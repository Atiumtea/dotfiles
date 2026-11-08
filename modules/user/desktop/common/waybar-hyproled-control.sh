#!/usr/bin/env bash
set -Eeuo pipefail

state_file="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hyproled/state.json"

choice="$(
    printf '%s\n' \
        "Fixed (1 position)" \
        "Linear horizontal (2 positions)" \
        "Linear vertical (2 positions)" \
        "Orbit 2x2 (4 positions)" \
        "Orbit 3x3 (9 positions)" \
        "Disable Pixel Shift" \
        "Disable all effects" |
        rofi -dmenu -i -p "Hyproled"
)" || exit 0

[[ -n "$choice" ]] || exit 0

case "$choice" in
    "Fixed (1 position)")
        mode="fixed"
        ;;
    "Linear horizontal (2 positions)")
        mode="linear-horizontal"
        ;;
    "Linear vertical (2 positions)")
        mode="linear-vertical"
        ;;
    "Orbit 2x2 (4 positions)")
        mode="orbit-2x2"
        ;;
    "Orbit 3x3 (9 positions)")
        mode="orbit-3x3"
        ;;
    "Disable Pixel Shift")
        [[ -f "$state_file" ]] || exit 0

        jq -e '
            type == "object" and
            .status == "active" and
            ((.pixelShift // false) | type == "boolean")
        ' "$state_file" >/dev/null || {
            printf 'hyproled: invalid or inactive state\n' >&2
            exit 1
        }

        pixel_shift=$(jq -r '.pixelShift // false' "$state_file")
        [[ "$pixel_shift" == true ]] || exit 0

        mask_enabled=$(jq -r '
            if .version >= 4 then .maskEnabled else true end
        ' "$state_file")

        if [[ "$mask_enabled" == true ]]; then
            hyproled --no-pixel-shift
        else
            hyproled off
        fi
        exit 0
        ;;
    "Disable all effects")
        [[ -e "$state_file" ]] || exit 0
        hyproled off
        exit 0
        ;;
    *)
        exit 1
        ;;
esac

if [[ -f "$state_file" ]]; then
    jq -e '
        type == "object" and .status == "active"
    ' "$state_file" >/dev/null || {
        printf 'hyproled: invalid or inactive state\n' >&2
        exit 1
    }

    pixel_shift=$(jq -r '.pixelShift // false' "$state_file")

    if [[ "$pixel_shift" == true ]]; then
        hyproled --pixel-shift-mode "$mode"
    else
        hyproled --pixel-shift --pixel-shift-mode "$mode"
    fi
else
    hyproled --pixel-shift --pixel-shift-mode "$mode"
fi
