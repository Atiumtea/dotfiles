#!/usr/bin/env bash
#
# NixOS rebuild helper built on top of `nh`.
# Safe, checked build/switch helper for this user's NixOS Flake.
# Default target: ~/dotfiles#x1extreme
#
# Usage: apply-boot.sh [command] [options]
#
# Commands:
#   check     Run alejandra --check and `nix flake check`
#   build     Build only; do not touch the current generation
#   diff      Build and show diff vs the running system (no apply)
#   dry-activate Build and preview activation without applying it
#   switch    Apply the configuration immediately (default) and tag the new generation
#   boot      Apply to the next boot only and tag the new generation
#   test      Apply temporarily; reverts on reboot (no tag is created)
#   update    Update flake inputs, then apply with switch (reverts lock on failure)
#   info      Show current generation and nh status
#
# Options:
#   --yes, -y        Skip confirmation prompts, including NH's confirmation
#   --host <name>    Override auto-detected hostname (useful for multiple hosts)
#   --force          Allow building even if the Git tree is dirty (skips tagging)
#   --trace          Enable detailed nh diagnostics (NH_LOG=nh=trace)
#   -h, --help       Show this help
#
set -euo pipefail
umask 077

# ─── Constants ────────────────────────────────────────────────────────────────
DOTFILES="${HOME}/dotfiles"
SNAPSHOT_DIR="${HOME}/snapshots"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S-%N)"

# ─── Defaults ─────────────────────────────────────────────────────────────────
COMMAND="switch"
UPDATE_INPUTS=false
ASSUME_YES=false
FORCE_BUILD=false
TRACE_NH=false
HOST="$(hostname -s 2>/dev/null || echo x1extreme)"

# ─── Help ─────────────────────────────────────────────────────────────────────
print_help() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    check|build|diff|dry-activate|switch|boot|test|update|info)
      COMMAND="$1"; shift ;;
    --yes|-y)         ASSUME_YES=true; shift ;;
    --host)           HOST="${2:?--host requires an argument}"; shift 2 ;;
    --force)          FORCE_BUILD=true; shift ;;
    --trace)          TRACE_NH=true; shift ;;
    -h|--help)        print_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; print_help; exit 1 ;;
  esac
done

# `update` implies updating inputs and switching
if [[ "$COMMAND" == "update" ]]; then
  UPDATE_INPUTS=true
  COMMAND="switch"
fi

mkdir -p "$SNAPSHOT_DIR"
chmod 700 "$SNAPSHOT_DIR"
LOG_FILE="${SNAPSHOT_DIR}/nixapply-${HOST}-${TIMESTAMP}.log"
BUILD_LOG_FILE="${SNAPSHOT_DIR}/nixapply-${HOST}-${TIMESTAMP}-build.log"

finish() {
  local status=$?
  local size tmp
  trap - EXIT
  if [[ -f "$LOG_FILE" ]]; then
    size=$(stat -c %s "$LOG_FILE" 2>/dev/null || printf '0')
    if [[ "$size" =~ ^[0-9]+$ ]] && ((size > 2097152)); then
      tmp="${LOG_FILE}.tmp"
      { printf '%s\n' '[Earlier output truncated; final 2 MiB retained]'; tail -c 2097152 "$LOG_FILE"; } > "$tmp" &&
        mv -f -- "$tmp" "$LOG_FILE" || rm -f -- "$tmp"
    fi
  fi
  if [[ -n "${NIXSNAP:-}" && -x "$NIXSNAP" ]]; then
    if ((status != 0)); then
      "$NIXSNAP" --log "$LOG_FILE" --no-clipboard >/dev/null 2>&1 || true
    else
      "$NIXSNAP" --rotate-only >/dev/null 2>&1 || true
    fi
  fi
  exit "$status"
}
trap finish EXIT

# ─── Sanity checks ────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your regular user, not as root." >&2
  exit 1
fi

if [[ ! -d "$DOTFILES" ]]; then
  echo "Repository not found: ${DOTFILES}" >&2
  exit 1
fi

if ! command -v nh >/dev/null 2>&1; then
  echo "ERROR: 'nh' is not in PATH. Enable it via programs.nh.enable = true;" >&2
  exit 1
fi

cd "$DOTFILES"

# Validate host exists in the flake
if ! nix eval ".#nixosConfigurations.${HOST}" --apply 'x: true' >/dev/null 2>&1; then
  echo "ERROR: Host '${HOST}' does not exist in the flake at ${DOTFILES}" >&2
  exit 1
fi

# Warn about dirty Git tree
if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "$FORCE_BUILD" == false ]]; then
    echo "ERROR: Git tree is dirty (uncommitted changes)." >&2
    echo "       Flakes only track committed files. To ensure reproducibility, please commit first:" >&2
    echo "         git add . && git commit -m \"your message\"" >&2
    echo "       Dirty files:" >&2
    git status --short >&2
    echo "       Or bypass this warning with --force (not recommended, tagging will be skipped)." >&2
    exit 1
  else
    echo "WARNING: Git tree is dirty. Proceeding because --force was used." >&2
    echo "         The resulting generation will not be tagged." >&2
    echo
  fi
fi

# Warn about stale flake.lock
if [[ -f "$DOTFILES/flake.lock" && "$UPDATE_INPUTS" == false ]]; then
  age_days=$(( ( $(date +%s) - $(stat -c %Y "$DOTFILES/flake.lock") ) / 86400 ))
  if [[ "$age_days" -gt 14 ]]; then
    echo "Note: flake.lock is ${age_days} days old. Consider 'apply-boot.sh update'."
    echo
  fi
fi

# Warn about low disk space
if [[ -d /nix ]]; then
  avail=$(df -BG --output=avail /nix 2>/dev/null | tail -1 | tr -d 'G ')
  if [[ -n "$avail" && "$avail" -lt 5 ]]; then
    echo "Warning: only ${avail}G free in /nix." >&2
  fi
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────
confirm() {
  $ASSUME_YES && return 0
  local prompt="$1"
  read -r -p "${prompt} [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

run_logged() {
  echo ">>> $*" | tee -a "$LOG_FILE"
  local status=0
  "$@" 2>&1 | tee -a "$LOG_FILE" || status=${PIPESTATUS[0]}
  return "$status"
}

run_nh() {
  echo ">>> $*" | tee -a "$LOG_FILE"
  local status=0

  # Keep both streams attached to the terminal:
  # nh's ROM renderer uses stderr for its live interface.
  # NH_ROM_LOG records the underlying Nix build stream separately.
  if [[ "$TRACE_NH" == true ]]; then
    NH_ROM=1 \
      NH_LOG=nh=trace \
      NH_ROM_LOG="$BUILD_LOG_FILE" \
      "$@" || status=$?
  else
    NH_ROM=1 \
      NH_ROM_LOG="$BUILD_LOG_FILE" \
      "$@" || status=$?
  fi

  return "$status"
}

# Get the current generation number from the profile link
get_generation() {
  local link
  link="$(readlink /nix/var/nix/profiles/system 2>/dev/null || true)"
  if [[ "$link" =~ system-([0-9]+)-link ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# ─── `check` ──────────────────────────────────────────────────────────────────
cmd_check() {
  echo "Running alejandra --check ..."
  if ! run_logged alejandra --check "$DOTFILES"; then
    echo "ERROR: formatting issues. Run 'alejandra .' to fix." >&2
    return 1
  fi

  echo
  echo "Running nix flake check ..."
  run_logged nix flake check "$DOTFILES" --no-build --show-trace
}

# ─── `diff` ───────────────────────────────────────────────────────────────────
cmd_diff() {
  echo "Building ${HOST} for comparison ..."
  local new_path
  new_path="$(nix build --no-link --print-out-paths --show-trace \
              --flake "${DOTFILES}#${HOST}" 2>>"$LOG_FILE")" || {
    echo "ERROR: build failed. Log: ${LOG_FILE}" >&2
    return 1
  }

  echo
  if command -v nvd >/dev/null 2>&1; then
    nvd diff /run/current-system "$new_path" | tee -a "$LOG_FILE"
  else
    echo "(nvd not installed; printing paths)"
    echo "current: $(readlink -f /run/current-system)"
    echo "new:     ${new_path}"
  fi
}

# ─── `info` ───────────────────────────────────────────────────────────────────
cmd_info() {
  echo "Host:      ${HOST}"
  echo "Flake:     ${DOTFILES}"
  echo "Current:   $(readlink -f /run/current-system)"
  echo
  echo "Generations:"
  nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -10 || true
  echo
  echo "nh version:"
  nh --version 2>/dev/null || true
}

# ─── `switch` / `boot` / `test` / `build` ─────────────────────────────────────
apply_via_nh() {
  local action="$1"
  local verb
  case "$action" in
    switch) verb="apply immediately" ;;
    dry-activate) verb="preview activation without applying it" ;;
    boot)   verb="apply to next boot" ;;
    test)   verb="apply temporarily (reverts on reboot)" ;;
    build)  verb="build only" ;;
  esac

  # Pre-flight checks
  if [[ "$action" == "switch" || "$action" == "boot" ]]; then
    echo "Running pre-flight checks ..."
    cmd_check || { echo "Pre-flight failed. Aborting." >&2; exit 1; }
    echo
  fi

  local old_gen
  old_gen=$(get_generation)

  echo "Host:   ${HOST}"
  echo "Flake:  ${DOTFILES}"
  echo "Action: nh os ${action} (${verb})"
  echo "Log:       ${LOG_FILE}"
  echo "Build log: ${BUILD_LOG_FILE}"
  if [[ "$TRACE_NH" == true ]]; then
    echo "nh trace:  enabled"
  fi
  echo

  if [[ "$action" != "build" && "$action" != "dry-activate" ]]; then
    confirm "Proceed?" || { echo "Cancelled."; exit 0; }
  fi

  local -a args=(nh os "$action" --hostname "$HOST" "$DOTFILES")
  $UPDATE_INPUTS && args+=(--update)

  # Disable NH's --ask confirmation through the environment when --yes was requested.
  $ASSUME_YES && export NH_ASK=0

  # Use the Nix daemon configuration as the single source of truth for build limits.

  local status=0
  run_nh "${args[@]}" || status=$?

  if [[ $status -ne 0 ]]; then
    echo
    echo "ERROR: 'nh os ${action}' failed (exit ${status}). Log: ${LOG_FILE}" >&2
    echo "Nix build log: ${BUILD_LOG_FILE}" >&2
    echo "Last nh diagnostics:" >&2
    tail -n 25 "$LOG_FILE" >&2 || true
    echo "Please review the log. If this was a pre-switch inhibitor, use 'boot' instead of 'switch'." >&2
    return "$status"
  fi

  # ─── Tagging Logic ──────────────────────────────────────────────────────────
  if [[ "$action" == "switch" || "$action" == "boot" ]]; then
    local new_gen branch_name tag_name tag_message

    new_gen="$(get_generation)"
    branch_name="$(git branch --show-current)"

    if [[ -z "$new_gen" ]]; then
      echo -e "\nWARNING: Could not determine the new generation number. Skipping tag creation." >&2
    elif [[ "$new_gen" == "$old_gen" ]]; then
      echo -e "\nNo new generation was created (stayed at gen-$old_gen). Skipping tag." >&2
    elif [[ "$FORCE_BUILD" == true ]]; then
      echo -e "\nWARNING: Skipping tag creation because the build was forced on a dirty tree." >&2
    else
      if [[ "$branch_name" == "main" ]]; then
        tag_name="gen-${new_gen}"
        tag_message="NixOS Generation ${new_gen}"
      else
        tag_name="gen-${new_gen}-exp"
        tag_message="Experimental NixOS Generation ${new_gen}"
      fi

      if git show-ref --verify --quiet "refs/tags/${tag_name}"; then
        echo -e "\nWARNING: Tag '$tag_name' already exists. Skipping." >&2
      else
        echo -e "\nCreating Git tag for this generation..."
        if git tag -a "$tag_name" -m "$tag_message"; then
          echo "Successfully created tag: $tag_name"
          echo "To view this tag later, run: git show $tag_name"
          echo "To push this tag later, run:"
          echo "git push origin refs/tags/$tag_name"
        else
          echo "WARNING: Failed to create tag '$tag_name'." >&2
        fi
      fi
    fi
  elif [[ "$action" == "test" ]]; then
    echo -e "\nNote: 'test' mode does not create a new generation, so no tag was created."
  fi

  if [[ "$action" == "boot" ]]; then
    echo -e "\nReboot when ready to activate the new generation."
  fi
}

# ──u─ Update flake inputs ──────────────────────────────────────────────────────
update_inputs() {
  echo "Updating flake inputs ..."
  if ! run_logged nix flake update "$DOTFILES"; then
    echo "ERROR: 'nix flake update' failed." >&2
    return 1
  fi
  echo "Inputs updated. Review 'git diff flake.lock'."
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────
if [[ "$UPDATE_INPUTS" == true && "$COMMAND" != "check" && "$COMMAND" != "diff" ]]; then
  update_inputs || exit 1
  echo
  
  # If we are updating, and the build/switch fails, we must revert the lock file
  if ! apply_via_nh "$COMMAND"; then
    echo
    echo "ERROR: Build failed after flake update." >&2
    echo "Reverting flake.lock to previous working state to prevent a broken repository..." >&2
    git checkout -- flake.lock
    echo "flake.lock reverted. Please fix the build errors manually." >&2
    exit 1
  fi
  exit 0
fi

case "$COMMAND" in
  check)  cmd_check ;;
  diff)   cmd_diff ;;
  info)   cmd_info ;;
  dry-activate) apply_via_nh dry-activate ;;
  build)  apply_via_nh build ;;
  switch) apply_via_nh switch ;;
  boot)   apply_via_nh boot ;;
  test)   apply_via_nh test ;;
  *) echo "Unknown command: ${COMMAND}" >&2; print_help; exit 1 ;;
esac

status=$?
if [[ $status -ne 0 ]]; then
  echo
  echo "Log saved: ${LOG_FILE}" >&2
  exit "$status"
fi