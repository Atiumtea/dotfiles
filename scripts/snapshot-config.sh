#!/usr/bin/env bash
#
# NixOS configuration snapshot.
#
# Usage:
#   ./snapshot-config.sh                  # quick snapshot (default)
#   ./snapshot-config.sh --core           # + core modules
#   ./snapshot-config.sh --full           # everything
#   ./snapshot-config.sh --host laptop    # override auto-detected host
#   ./snapshot-config.sh --user ushki     # override auto-detected user
#   ./snapshot-config.sh --diff           # replace file contents with git diff
#   ./snapshot-config.sh --store          # add top-20 store paths by size
#   ./snapshot-config.sh --no-git         # skip git log section
#   ./snapshot-config.sh --help
#
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
DOTFILES="${HOME}/dotfiles"
SNAPSHOT_DIR="${HOME}/snapshots"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"

# ─── Defaults ─────────────────────────────────────────────────────────────────
MODE="quick"
HOST="$(uname -n 2>/dev/null || echo 'unknown')"
USERNAME="${USER:-$(id -un)}"
INCLUDE_STORE=false
DIFF_MODE=false
INCLUDE_GIT=true

# ─── Help ─────────────────────────────────────────────────────────────────────
print_help() {
  cat <<'EOF'
Usage: snapshot-config.sh [OPTIONS]

Options:
  --quick          Quick snapshot (default): host config + lib only.
  --core           Core modules: system/user defaults, hardware, hyprland, shells.
  --full           Everything: nixvim, themes, scripts, full desktop config.
  --host <name>    Override auto-detected hostname (default: `uname -n`).
  --user <name>    Override auto-detected username (default: $USER).
  --diff           Replace file contents with `git diff HEAD~1`.
  --store          Add top-20 store paths by size (requires `result` symlink).
  --no-git         Skip the git log section in the header.
  -h, --help       Show this help message.

Examples:
  snapshot-config.sh --core
  snapshot-config.sh --full --host laptop --user ushki
  snapshot-config.sh --diff --store
EOF
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)   MODE="quick"; shift ;;
    --core)    MODE="core";  shift ;;
    --full)    MODE="full";  shift ;;
    --host)    HOST="${2:?--host requires an argument}"; shift 2 ;;
    --user)    USERNAME="${2:?--user requires an argument}"; shift 2 ;;
    --diff)    DIFF_MODE=true; shift ;;
    --store)   INCLUDE_STORE=true; shift ;;
    --no-git)  INCLUDE_GIT=false; shift ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; print_help; exit 1 ;;
  esac
done

OUTFILE="${SNAPSHOT_DIR}/nixos-${HOST}-${MODE}-${TIMESTAMP}.md"

# ─── File lists by level ──────────────────────────────────────────────────────
# Paths are relative to $DOTFILES. Order defines section order in the snapshot.

BASE_FILES=(
  "flake.nix"
  "lib/default.nix"
  "hosts/${HOST}/default.nix"
  "hosts/${HOST}/configuration.nix"
  "hosts/${HOST}/hardware-configuration.nix"
  "hosts/${HOST}/hardware-configuration-additional.nix"
  "hosts/${HOST}/home-${USERNAME}.nix"
)

CORE_FILES=(
  # System
  "modules/system/default.nix"
  "modules/system/configuration.nix"
  "modules/system/users.nix"
  "modules/system/audio.nix"
  "modules/system/gaming.nix"
  "modules/system/mullvad.nix"
  "modules/system/virtualization.nix"

  # System / hardware
  "modules/system/hardware/default.nix"
  "modules/system/hardware/bluetooth.nix"
  "modules/system/hardware/laptop.nix"
  "modules/system/hardware/graphics/default.nix"
  "modules/system/hardware/graphics/nvidia.nix"

  # System / other
  "modules/system/kernel/default.nix"
  "modules/system/security/default.nix"
  "modules/system/sddm/default.nix"
  "modules/system/desktop/default.nix"
  "modules/system/desktop/hyprland.nix"
  "modules/system/styling/default.nix"
  "modules/system/styling/stylix.nix"
  "modules/system/styling/fonts.nix"

  # User / entry points
  "modules/user/default.nix"
  "modules/user/home.nix"
  "modules/user/git.nix"
  "modules/user/security.nix"
  "modules/user/xdg.nix"
  "modules/user/mullvad.nix"

  # User / shells
  "modules/user/shells/default.nix"
  "modules/user/shells/zsh.nix"

  # User / browsers and terminals
  "modules/user/browsers/default.nix"
  "modules/user/browsers/firefox.nix"
  "modules/user/terminals/default.nix"
  "modules/user/terminals/kitty.nix"

  # User / styling
  "modules/user/styling/default.nix"
  "modules/user/styling/cursors.nix"
  "modules/user/styling/fonts.nix"
  "modules/user/styling/stylix.nix"

  # User / desktop (Hyprland)
  "modules/user/desktop/default.nix"
  "modules/user/desktop/hyprland/default.nix"
  "modules/user/desktop/hyprland/hyprland.nix"
  "modules/user/desktop/hyprland/hypridle.nix"
  "modules/user/desktop/hyprland/hyprlock.nix"
  "modules/user/desktop/hyprland/hyprsunset.nix"
  "modules/user/desktop/common/default.nix"
  "modules/user/desktop/common/rofi.nix"
  "modules/user/desktop/common/waybar.nix"
)

FULL_FILES=(
  # Extra system modules
  "modules/system/desktop/niri.nix"
  "modules/system/iriun/default.nix"
  "modules/system/iriun/iriun.nix"
  "modules/system/kernel/tty0tty.nix"
  "modules/system/postgresql/default.nix"
  "modules/system/styling/grub/default.nix"
  "modules/system/styling/grub/themes/cybergrub-2077/theme.nix"
  "modules/system/styling/plymouth/default.nix"
  "modules/system/styling/plymouth/themes/arasaka/theme.nix"
  "modules/system/styling/plymouth/themes/ecorp-glitch/theme.nix"

  # Active theme
  "modules/themes/dune/default.nix"

  # User / editors
  "modules/user/editors/default.nix"
  "modules/user/editors/idea.nix"
  "modules/user/editors/nixvim/default.nix"
  "modules/user/editors/nixvim/keymaps.nix"
  "modules/user/editors/nixvim/opts.nix"
  "modules/user/editors/nixvim/plugins/default.nix"
  "modules/user/editors/nixvim/plugins/cmp.nix"
  "modules/user/editors/nixvim/plugins/conform.nix"
  "modules/user/editors/nixvim/plugins/dadbod.nix"
  "modules/user/editors/nixvim/plugins/git.nix"
  "modules/user/editors/nixvim/plugins/lsp.nix"
  "modules/user/editors/nixvim/plugins/misc.nix"
  "modules/user/editors/nixvim/plugins/telescope.nix"
  "modules/user/editors/nixvim/plugins/treesitter.nix"
  "modules/user/editors/nixvim/plugins/trouble.nix"
  "modules/user/editors/nixvim/plugins/typst.nix"
  "modules/user/editors/nixvim/plugins/which-key.nix"

  # User / misc
  "modules/user/misc/default.nix"
  "modules/user/misc/music.nix"

  # User / desktop (Niri)
  "modules/user/desktop/niri/default.nix"
  "modules/user/desktop/niri/niri.nix"

  # Misc
  "alejandra.toml"
  "scripts/apply-boot.sh"
)

# ─── Select final file list based on mode ─────────────────────────────────────
case "$MODE" in
  quick) FILES=("${BASE_FILES[@]}") ;;
  core)  FILES=("${BASE_FILES[@]}" "${CORE_FILES[@]}") ;;
  full)  FILES=("${BASE_FILES[@]}" "${CORE_FILES[@]}" "${FULL_FILES[@]}") ;;
esac

# ─── Section builders ─────────────────────────────────────────────────────────
build_store_section() {
  local result_link="${DOTFILES}/result"

  if [[ ! -L "$result_link" ]]; then
    echo "_No \`result\` symlink in \`${DOTFILES}\`. Run \`nixos-rebuild build --flake .#${HOST}\` first._"
    return
  fi

  local target
  target="$(readlink -f "$result_link" 2>/dev/null || true)"
  if [[ -z "$target" ]]; then
    echo "_Failed to resolve \`result\` symlink._"
    return
  fi

  if ! command -v nix >/dev/null 2>&1; then
    echo "_The \`nix\` command is not available._"
    return
  fi

  echo "Closure root: \`${target}\`"
  echo
  echo "### Top-20 store paths by size"
  echo
  echo '```'
  nix path-info -rSh "$target" 2>/dev/null \
    | sort -k2 -h \
    | tail -20 \
    || echo "(nix path-info failed)"
  echo '```'
  echo
  echo "### Total closure size"
  echo
  echo '```'
  if command -v jq >/dev/null 2>&1; then
    nix path-info -rSh --json "$target" 2>/dev/null \
      | jq -r '[.[].narSize] | add | . / 1024 / 1024 | "\(. | floor) MiB"'
  else
    echo "(requires jq)"
  fi
  echo '```'
}

build_files_section() {
  if [[ "$DIFF_MODE" == true ]]; then
    echo "## Recent changes"
    echo
    if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo '```diff'
      if git -C "$DOTFILES" rev-parse HEAD~1 >/dev/null 2>&1; then
        git -C "$DOTFILES" diff HEAD~1 2>/dev/null || echo "(git diff failed)"
      else
        echo "(less than two commits; falling back to working tree diff)"
        git -C "$DOTFILES" diff 2>/dev/null || echo "(no changes)"
      fi
      echo '```'
    else
      echo "_Not a git repository; cannot produce a diff._"
    fi
    return
  fi

  echo "## File contents"
  echo
  local f full
  for f in "${FILES[@]}"; do
    full="${DOTFILES}/${f}"
    echo "### \`${f}\`"
    echo
    if [[ -f "$full" ]]; then
      echo '```nix'
      cat "$full"
      echo '```'
    else
      echo "_File not found: \`${full}\`._"
    fi
    echo
  done
}

# ─── Gather header metadata ───────────────────────────────────────────────────
GIT_LOG=""
if [[ "$INCLUDE_GIT" == true ]] && git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_LOG="$(git -C "$DOTFILES" log -n 10 --pretty=format:'%h %ad %s' --date=short 2>/dev/null || true)"
fi

FLAKE_METADATA=""
if command -v nix >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  FLAKE_METADATA="$(nix flake metadata "$DOTFILES" --json 2>/dev/null \
    | jq -r '.locks.nodes | to_entries[] | select(.value.locked) | "\(.key): \(.value.locked.owner // "?")/\(.value.locked.repo // "?") @ \(.value.locked.rev // "?")"' 2>/dev/null \
    || true)"
fi

# ─── Generate snapshot ────────────────────────────────────────────────────────
mkdir -p "$SNAPSHOT_DIR"

{
  echo "# NixOS Config Snapshot — ${HOST}"
  echo
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| Host | \`${HOST}\` |"
  echo "| User | \`${USERNAME}\` |"
  echo "| Mode | \`${MODE}\` |"
  echo "| Diff mode | \`${DIFF_MODE}\` |"
  echo "| Store report | \`${INCLUDE_STORE}\` |"
  echo "| Snapshot date | $(date '+%Y-%m-%d %H:%M:%S %Z') |"
  echo "| Home directory | \`${HOME}\` |"
  echo "| Repository | \`${DOTFILES}\` |"
  echo "| Files in snapshot | ${#FILES[@]} |"
  echo

  if [[ -n "$GIT_LOG" ]]; then
    echo "---"
    echo
    echo "## Recent commits"
    echo
    echo '```'
    echo "$GIT_LOG"
    echo '```'
    echo
  fi

  if [[ -n "$FLAKE_METADATA" ]]; then
    echo "---"
    echo
    echo "## Locked inputs (from flake.lock)"
    echo
    echo '```'
    echo "$FLAKE_METADATA"
    echo '```'
    echo
  fi

  if [[ "$INCLUDE_STORE" == true ]]; then
    echo "---"
    echo
    echo "## Store usage"
    echo
    build_store_section
    echo
  fi

  echo "---"
  echo
  build_files_section

  echo "---"
  echo
  echo "_Snapshot generated by \`snapshot-config.sh\` (mode: \`${MODE}\`)._"
} > "$OUTFILE"

# ─── Copy to clipboard ────────────────────────────────────────────────────────
CLIP_TOOL="not found"
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy < "$OUTFILE"
  CLIP_TOOL="wl-copy (Wayland)"
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard < "$OUTFILE"
  CLIP_TOOL="xclip (X11)"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
BYTES=$(wc -c < "$OUTFILE")
LINES=$(wc -l < "$OUTFILE")
MISSING=$(grep -c '^_File not found' "$OUTFILE" 2>/dev/null || echo 0)

echo "✓ Snapshot ready"
echo "  Mode:          ${MODE}"
echo "  Host:          ${HOST}"
echo "  Diff mode:     ${DIFF_MODE}"
echo "  Store report:  ${INCLUDE_STORE}"
echo "  File:          ${OUTFILE}"
echo "  Size:          ${BYTES} bytes / ${LINES} lines"
echo "  Missing files: ${MISSING}"
echo "  Clipboard:     ${CLIP_TOOL}"
