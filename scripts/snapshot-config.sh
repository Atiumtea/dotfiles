#!/usr/bin/env bash
set -u
umask 077

SNAPSHOT_DIR="${HOME}/snapshots"
DOTFILES="${HOME}/dotfiles"
HOST="$(hostname -s 2>/dev/null || hostname)"
HOST="${HOST//[^[:alnum:]._-]/_}"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S-%N)"
LOG_FILE=""
COPY_CLIPBOARD=true
ROTATE_ONLY=false
PURGE_LEGACY=false
INCLUDE_JOURNAL=false

print_help() {
  printf '%s\n' 'Usage: nixsnap [--log FILE] [--journal] [--no-clipboard] [--rotate-only] [--purge-legacy]'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log) LOG_FILE="${2:?--log requires a file}"; shift 2 ;;
    --journal) INCLUDE_JOURNAL=true; shift ;;
    --no-clipboard) COPY_CLIPBOARD=false; shift ;;
    --rotate-only) ROTATE_ONLY=true; shift ;;
    --purge-legacy) PURGE_LEGACY=true; shift ;;
    -h|--help) print_help; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; print_help >&2; exit 2 ;;
  esac
done

mkdir -p "$SNAPSHOT_DIR"
chmod 700 "$SNAPSHOT_DIR"

rotate() {
  local file
  local -a stale=()
  mapfile -t stale < <(
    find "$SNAPSHOT_DIR" -maxdepth 1 -type f \
      \( -name 'diagnostic-*.md' -o -name 'nixapply-*.log' \) \
      -printf '%T@ %p\n' | sort -rn | sed -n '101,$s/^[^ ]* //p'
  )
  for file in "${stale[@]}"; do
    rm -f -- "$file"
  done
}

if [[ "$ROTATE_ONLY" == true ]]; then
  rotate
  exit 0
fi

if [[ "$PURGE_LEGACY" == true ]]; then
  mapfile -d '' -t legacy < <(
    find "$SNAPSHOT_DIR" -maxdepth 1 -type f \
      \( -name 'nixos-*.md' -o -name 'rebuild-*.log' \) -print0
  )
  if ((${#legacy[@]} == 0)); then
    printf '%s\n' 'No legacy snapshots found.'
    exit 0
  fi
  printf 'Legacy files to delete (%s):\n' "${#legacy[@]}"
  printf '  %s\n' "${legacy[@]}"
  read -r -p 'Delete these files? [y/N] ' answer
  case "$answer" in
    y|Y|yes|YES) rm -f -- "${legacy[@]}" ;;
    *) printf '%s\n' 'Cancelled.'; exit 0 ;;
  esac
  rotate
  printf '%s\n' 'Legacy files removed.'
  exit 0
fi

capture() {
  local title="$1"
  shift
  printf '### %s\n\n```text\n' "$title"
  if command -v "$1" >/dev/null 2>&1; then
    "$@" 2>&1 | sed -n '1,120p'
    local status=${PIPESTATUS[0]}
    if ((status != 0)); then
      printf '[exit status: %s]\n' "$status"
    fi
  else
    printf 'unavailable\n'
  fi
  printf '```\n\n'
}

write_power() {
  local device field value found=false
  printf '### Battery and backlight\n\n```text\n'
  for device in /sys/class/power_supply/BAT*; do
    [[ -d "$device" ]] || continue
    found=true
    printf '%s\n' "${device##*/}"
    for field in status capacity charge_control_start_threshold charge_control_end_threshold; do
      if [[ -r "$device/$field" ]]; then
        read -r value < "$device/$field"
        printf '  %s: %s\n' "$field" "$value"
      fi
    done
  done
  for device in /sys/class/backlight/*; do
    [[ -d "$device" ]] || continue
    found=true
    printf '%s\n' "${device##*/}"
    for field in brightness max_brightness; do
      if [[ -r "$device/$field" ]]; then
        read -r value < "$device/$field"
        printf '  %s: %s\n' "$field" "$value"
      fi
    done
  done
  [[ "$found" == true ]] || printf 'no battery or backlight devices\n'
  printf '```\n\n'
}

OUTFILE="${SNAPSHOT_DIR}/diagnostic-${HOST}-${TIMESTAMP}.md"
TMPFILE="$(mktemp "${SNAPSHOT_DIR}/.diagnostic.XXXXXX")"
trap 'rm -f -- "$TMPFILE"' EXIT

{
  printf '# NixOS diagnostic\n\nGenerated: %s\nHost: %s\nUser: %s\n\n' \
    "$(date --iso-8601=seconds)" "$HOST" "${USER:-unknown}"

  printf '## System\n\n'
  capture 'NixOS' nixos-version
  capture 'Kernel' uname -a
  capture 'Uptime' uptime -p
  capture 'Nix' nix --version

  printf '## Active generations\n\n'
  capture 'Current system' readlink -f /run/current-system
  capture 'Booted system' readlink -f /run/booted-system
  capture 'Recent system generations' bash -c 'nix-env -p /nix/var/nix/profiles/system --list-generations | tail -n 8'
  capture 'Home Manager profile' readlink -f "${HOME}/.local/state/nix/profiles/home-manager"

  printf '## Local configuration state\n\n'
  if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    capture 'Repository revision' git -C "$DOTFILES" log -1 --format='%H%n%ad%n%s' --date=iso-strict
    capture 'Working tree' git -C "$DOTFILES" status --short --branch
    capture 'Unstaged change summary' git -C "$DOTFILES" diff --stat
    capture 'Staged change summary' git -C "$DOTFILES" diff --cached --stat
    capture 'Flake lock checksum' sha256sum "${DOTFILES}/flake.lock"
  else
    printf 'Repository unavailable: %s\n\n' "$DOTFILES"
  fi

  printf '## Hardware and resources\n\n'
  capture 'CPU' lscpu
  capture 'Memory' free -h
  capture 'PCI devices and drivers' lspci -nnk
  capture 'Block devices' lsblk -e7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
  capture 'Filesystem space' df -hT / /nix /home
  capture 'GPU status' nvidia-smi --query-gpu=name,driver_version,temperature.gpu,pstate,memory.total --format=csv,noheader
  capture 'Sensors' sensors
  write_power

  printf '## Desktop session\n\n'
  capture 'Hyprland version' hyprctl version
  if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    printf '### Monitors\n\n```json\n'
    hyprctl monitors -j 2>/dev/null | jq -c '[.[] | {name, width, height, refreshRate, scale, transform, focused}]' 2>/dev/null || printf 'unavailable\n'
    printf '```\n\n'
  fi
  capture 'Waybar version' waybar --version

  printf '## Service health\n\n'
  capture 'Failed system services' systemctl --failed --no-legend --plain
  capture 'Failed user services' systemctl --user --failed --no-legend --plain
  capture 'Flatpak applications' flatpak list --app --columns=application,branch,version

  if [[ "$INCLUDE_JOURNAL" == true ]]; then
    printf '### Current boot errors\n\n```text\n'
    journalctl -b -p err..alert --no-pager -n 60 -o short-iso 2>&1 | sed -n '1,60p' | sed -E \
      -e 's/((password|passwd|token|secret|api[_-]?key|authorization)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
      -e 's#(https?://)[^/@:]+:[^/@]+@#\1[REDACTED]@#g' \
      -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1[REDACTED]/Ig'
    printf '```\n\n'
  fi

  if [[ -n "$LOG_FILE" ]]; then
    printf '## nixapply log excerpt\n\n'
    if [[ -f "$LOG_FILE" ]]; then
      printf 'Source: %s\n\n```text\n' "$LOG_FILE"
      tail -n 100 "$LOG_FILE" | sed -E \
        -e 's/((password|passwd|token|secret|api[_-]?key|authorization)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig' \
        -e 's#(https?://)[^/@:]+:[^/@]+@#\1[REDACTED]@#g' \
        -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/-]+/\1[REDACTED]/Ig'
      printf '```\n\n'
    else
      printf 'Log file not found: %s\n\n' "$LOG_FILE"
    fi
  fi

  printf '%s\n' '---' '' 'No configuration file contents or diffs are included.'
} > "$TMPFILE"

mv -- "$TMPFILE" "$OUTFILE"
rotate

CLIPBOARD='not requested'
if [[ "$COPY_CLIPBOARD" == true ]]; then
  if command -v wl-copy >/dev/null 2>&1 && wl-copy < "$OUTFILE"; then
    CLIPBOARD='copied with wl-copy'
  elif command -v xclip >/dev/null 2>&1 && xclip -selection clipboard < "$OUTFILE"; then
    CLIPBOARD='copied with xclip'
  else
    CLIPBOARD='unavailable'
  fi
fi

printf 'Diagnostic snapshot: %s\nSize: %s bytes\nClipboard: %s\n' \
  "$OUTFILE" "$(wc -c < "$OUTFILE")" "$CLIPBOARD"
