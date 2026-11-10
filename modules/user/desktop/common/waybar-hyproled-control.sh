#!/usr/bin/env bash
set -Eeuo pipefail

state_file="${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hyproled/state.json"
preferences_file="${XDG_STATE_HOME:-$HOME/.local/state}/hyproled/preferences.json"
theme_file="${HYPROLED_ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/hyproled.rasi}"

source_file=""
if [[ -f "$state_file" ]]; then
    jq -e '
        type == "object" and
        (.version == 1 or .version == 2 or .version == 3 or .version == 4 or .version == 5) and
        (.status == "active" or .status == "applying" or .status == "restoring")
    ' "$state_file" >/dev/null || {
        printf 'hyproled: invalid runtime state; refusing to open controls\n' >&2
        exit 1
    }
    source_file="$state_file"
elif [[ -f "$preferences_file" ]]; then
    jq -e '
        type == "object" and .version == 1 and
        (.maskEnabled | type == "boolean") and
        (.pixelShift | type == "boolean") and
        (.pixelShiftMode | type == "string") and
        (.pixelShiftIndex | type == "number") and
        (.phase | type == "number") and
        (.offPixels | type == "number") and
        (.brightnessCompensationEnabled | type == "boolean")
    ' "$preferences_file" >/dev/null || {
        printf 'hyproled: invalid preferences file; refusing to open controls\n' >&2
        exit 1
    }
    source_file="$preferences_file"
fi

read_setting() {
    local expression="$1" fallback="$2"
    if [[ -n "$source_file" ]]; then
        jq -r "$expression // $fallback" "$source_file"
    else
        printf '%s\n' "$fallback"
    fi
}

mask_enabled=$(read_setting 'if has("status") then (if .version >= 4 then .maskEnabled else true end) else .maskEnabled end' false)
pixel_shift=$(read_setting '.pixelShift' false)
pixel_shift_mode=$(read_setting '.pixelShiftMode' '"orbit-2x2"')
brightness_compensation=$(read_setting '.brightnessCompensationEnabled // .brightnessEnabled' false)

activate_pixel_shift_mode() {
    local mode="$1"
    if [[ "$pixel_shift" == true ]]; then
        hyproled --pixel-shift-mode "$mode"
    else
        hyproled --pixel-shift --pixel-shift-mode "$mode"
    fi
}

run_rofi() {
    local prompt="$1"
    shift
    local output status
    set +e
    output=$(printf '%s\n' "$@" | rofi -dmenu -i -no-sort -no-custom -l 7 \
        -location 0 \
        -p "$prompt" \
        -theme "$theme_file" \
        -kb-move-char-back Control+b \
        -kb-move-char-forward Control+f \
        -kb-custom-1 Right \
        -kb-custom-2 Left)
    status=$?
    set -e
    ROFI_OUTPUT="$output"
    return "$status"
}

page=0
while true; do
    status=0
    if [[ "$page" == 0 ]]; then
        options=(
            "Orbit 2x2 (default)"
            "Orbit 3x3"
            "Linear horizontal"
            "Linear vertical"
            "$([[ "$pixel_shift" == true ]] && printf 'Disable' || printf 'Enable') Pixel Shift"
            "Disable all effects"
            "Mask & Brightness  →"
        )
        run_rofi "Hyproled  /  Pixel Shift" "${options[@]}" || status=$?
    else
        options=(
            "$([[ "$mask_enabled" == true ]] && printf 'Disable' || printf 'Enable') mask"
            "1 pixel disabled"
            "2 pixels disabled"
            "3 pixels disabled"
            "$([[ "$brightness_compensation" == true ]] && printf 'Disable' || printf 'Enable') brightness compensation"
            "Disable all effects"
            "←  Pixel Shift"
        )
        run_rofi "Hyproled  /  Mask & Brightness" "${options[@]}" || status=$?
    fi

    case "${status:-0}" in
        10) page=1; continue ;;
        11) page=0; continue ;;
        1|255) exit 0 ;;
        0) ;;
        *) exit 0 ;;
    esac

    choice="$ROFI_OUTPUT"
    [[ -n "$choice" ]] || exit 0

    if [[ "$page" == 0 ]]; then
        case "$choice" in
            "Orbit 2x2 (default)") activate_pixel_shift_mode orbit-2x2 ;;
            "Orbit 3x3") activate_pixel_shift_mode orbit-3x3 ;;
            "Linear horizontal") activate_pixel_shift_mode linear-horizontal ;;
            "Linear vertical") activate_pixel_shift_mode linear-vertical ;;
            "Enable Pixel Shift") hyproled --pixel-shift --pixel-shift-mode "$pixel_shift_mode" ;;
            "Disable Pixel Shift")
                if [[ "$mask_enabled" == true ]]; then
                    hyproled --no-pixel-shift
                else
                    hyproled off
                fi
                ;;
            "Disable all effects") hyproled off ;;
            "Mask & Brightness  →") page=1; continue ;;
            *) exit 1 ;;
        esac
    else
        case "$choice" in
            "Enable mask") hyproled --mask ;;
            "Disable mask")
                if [[ "$pixel_shift" == true ]]; then
                    hyproled --no-mask
                else
                    hyproled off
                fi
                ;;
            "1 pixel disabled") hyproled --disabled-pixels 1 ;;
            "2 pixels disabled") hyproled --disabled-pixels 2 ;;
            "3 pixels disabled") hyproled --disabled-pixels 3 ;;
            "Enable brightness compensation") hyproled --brightness-compensation ;;
            "Disable brightness compensation") hyproled --no-brightness-compensation ;;
            "Disable all effects") hyproled off ;;
            "←  Pixel Shift") page=0; continue ;;
            *) exit 1 ;;
        esac
    fi
    exit 0
done
