#!/usr/bin/env bash
set -Eeuo pipefail

state_file="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hyproled/state.json"

state_exists() {
    [[ -e "$state_file" || -L "$state_file" ]]
}

validate_active_state() {
    jq -e '
        type == "object" and
        (.version == 1 or .version == 2 or .version == 3 or .version == 4 or .version == 5) and
        .status == "active" and
        (if .version >= 3 then
            (.pixelShift | type == "boolean")
         else true end) and
        (if .version >= 4 then
            (.maskEnabled | type == "boolean")
         else true end)
    ' "$state_file" >/dev/null || {
        printf 'hyproled: invalid or inactive state\n' >&2
        return 1
    }
}

choice="$(
    printf '%s\n' \
        "Orbit 2x2 (default)" \
        "Orbit 3x3" \
        "Linear horizontal" \
        "Linear vertical" \
        "Enable mask" \
        "Disable Pixel Shift" \
        "Disable all effects" |
        rofi -dmenu -i -no-sort -no-custom -l 7 \
            -location 0 \
            -p "Hyproled" \
            -theme-str 'window { width: 320px; } listview { lines: 7; fixed-height: false; }'
)" || exit 0

[[ -n "$choice" ]] || exit 0

case "$choice" in
    "Orbit 2x2 (default)")
        mode="orbit-2x2"
        ;;
    "Orbit 3x3")
        mode="orbit-3x3"
        ;;
    "Linear horizontal")
        mode="linear-horizontal"
        ;;
    "Linear vertical")
        mode="linear-vertical"
        ;;

    "Enable mask")
        if state_exists; then
            validate_active_state || exit 1

            mask_enabled=$(jq -r '
                if .version >= 4 then .maskEnabled else true end
            ' "$state_file")

            # Do not recalculate brightness when the mask is already active.
            [[ "$mask_enabled" == false ]] || exit 0
        fi

        # Enables the mask while preserving an existing Pixel Shift session.
        hyproled
        exit 0
        ;;

    "Disable Pixel Shift")
        state_exists || exit 0
        validate_active_state || exit 1

        pixel_shift=$(jq -r '
            if .version >= 3 then .pixelShift else false end
        ' "$state_file")

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
        if state_exists; then
            hyproled off
        fi
        exit 0
        ;;

    *)
        exit 1
        ;;
esac

if state_exists; then
    validate_active_state || exit 1

    pixel_shift=$(jq -r '
        if .version >= 3 then .pixelShift else false end
    ' "$state_file")

    if [[ "$pixel_shift" == true ]]; then
        hyproled --pixel-shift-mode "$mode"
    else
        hyproled --pixel-shift --pixel-shift-mode "$mode"
    fi
else
    hyproled --pixel-shift --pixel-shift-mode "$mode"
fi
