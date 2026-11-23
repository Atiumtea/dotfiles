#!/usr/bin/env bash
set -Eeuo pipefail

theme_file="${NIXOS_CONTROL_ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/hyproled.rasi}"

options=(
    "System information"
    "Build configuration"
    "Preview activation"
    "Switch immediately"
    "Apply on next boot"
    "Test until reboot"
)

choice="$(printf '%s\n' "${options[@]}" | rofi \
    -dmenu \
    -i \
    -no-sort \
    -no-custom \
    -l 6 \
    -location 0 \
    -p "NixOS Control" \
    -theme "$theme_file")" || exit 0

case "$choice" in
    "System information") action="info" ;;
    "Build configuration") action="build" ;;
    "Preview activation") action="dry-activate" ;;
    "Switch immediately") action="switch" ;;
    "Apply on next boot") action="boot" ;;
    "Test until reboot") action="test" ;;
    *) exit 0 ;;
esac

# NH_FLAKE is set by the wrapper from programs.nh.flake.
# --hold keeps the full NH output visible after the command exits.
exec kitty --title "NixOS Control · ${choice}" --hold nh os "$action"
