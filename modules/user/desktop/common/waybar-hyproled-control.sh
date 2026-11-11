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
        (.offPixels | type == "number" and floor == . and . >= 1 and . <= 3) and
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
pixel_shift_mode=$(read_setting 'if has("status") and .version < 5 and (.pixelShift // false) then "fixed" else .pixelShiftMode end' '"orbit-2x2"')
off_pixels=$(read_setting '.offPixels' 1)
brightness_compensation=$(read_setting 'if .brightnessCompensationEnabled != null then .brightnessCompensationEnabled else (.brightnessEnabled // false) end' false)

case "$pixel_shift_mode" in
    fixed|orbit-2x2|orbit-3x3|linear-horizontal|linear-vertical) ;;
    *) printf 'hyproled: invalid Pixel Shift mode in saved state\n' >&2; exit 1 ;;
esac
[[ "$off_pixels" =~ ^[1-3]$ ]] || {
    printf 'hyproled: invalid mask pixel count in saved state\n' >&2
    exit 1
}

activate_pixel_shift_mode() {
    local mode="$1"
    local -a args=(--pixel-shift-mode "$mode")

    # Selecting a Pixel Shift mode activates Pixel Shift only. The mask state
    # is deliberately left untouched.
    [[ "$pixel_shift" == true ]] || args+=(--pixel-shift)
    hyproled "${args[@]}"
}

activate_mask_mode() {
    local count="$1"

    # Selecting a mask density activates the mask only. Pixel Shift remains
    # in its current state and position.
    hyproled --mask --disabled-pixels "$count"
}

run_rofi() {
    local prompt="$1"
    local message="$2"
    local active_row="$3"
    shift 3

    local output status
    local -a rofi_args=(
        -dmenu
        -i
        -no-sort
        -no-custom
        -format i
        -markup-rows
        -l 8
        -location 0
        -p "$prompt"
        -mesg "$message"
        -theme "$theme_file"
        -kb-move-char-back Control+b
        -kb-move-char-forward Control+f
        -kb-custom-1 Right
        -kb-custom-2 Left
    )
    [[ -n "$active_row" ]] && rofi_args+=(-a "$active_row")

    set +e
    output=$(printf '%s\n' "$@" | rofi "${rofi_args[@]}")
    status=$?
    set -e

    ROFI_OUTPUT="$output"
    return "$status"
}

page=0
while true; do
    status=0
    active_row=""

    if [[ "$page" == 0 ]]; then
        if [[ "$pixel_shift" == true ]]; then
            pixel_shift_toggle="<b>Disable Pixel Shift</b>"
            case "$pixel_shift_mode" in
                fixed) active_row=2 ;;
                orbit-2x2) active_row=3 ;;
                orbit-3x3) active_row=4 ;;
                linear-horizontal) active_row=5 ;;
                linear-vertical) active_row=6 ;;
            esac
        else
            pixel_shift_toggle="<b>Enable Pixel Shift</b>"
        fi

        options=(
            "$pixel_shift_toggle"
            "<b>Advance all active effects now</b>"
            "Fixed"
            "Orbit 2x2 (default)"
            "Orbit 3x3"
            "Linear horizontal"
            "Linear vertical"
            "<b>Disable all effects</b>"
        )
        run_rofi "Hyproled  /  Pixel Shift" "→  Mask &amp; Brightness" "$active_row" "${options[@]}" || status=$?
    else
        if [[ "$mask_enabled" == true ]]; then
            mask_toggle="<b>Disable mask</b>"
            active_row=$((off_pixels + 1))
        else
            mask_toggle="<b>Enable mask</b>"
        fi

        if [[ "$brightness_compensation" == true ]]; then
            brightness_toggle="Disable brightness compensation"
        else
            brightness_toggle="Enable brightness compensation"
        fi

        options=(
            "$mask_toggle"
            "<b>Advance all active effects now</b>"
            "1 pixel disabled"
            "2 pixels disabled"
            "3 pixels disabled"
            "$brightness_toggle"
            "<b>Disable all effects</b>"
        )
        run_rofi "Hyproled  /  Mask & Brightness" "←  Pixel Shift" "$active_row" "${options[@]}" || status=$?
    fi

    case "$status" in
        10) page=1; continue ;;
        11) page=0; continue ;;
        1|255) exit 0 ;;
        0) ;;
        *) exit "$status" ;;
    esac

    choice="$ROFI_OUTPUT"
    [[ "$choice" =~ ^[0-7]$ ]] || exit 0

    if [[ "$page" == 0 ]]; then
        case "$choice" in
            0)
                if [[ "$pixel_shift" == true ]]; then
                    if [[ "$mask_enabled" == true ]]; then
                        hyproled --no-pixel-shift
                    else
                        hyproled off
                    fi
                else
                    hyproled --pixel-shift --pixel-shift-mode "$pixel_shift_mode"
                fi
                ;;
            1) hyproled -s ;;
            2) activate_pixel_shift_mode fixed ;;
            3) activate_pixel_shift_mode orbit-2x2 ;;
            4) activate_pixel_shift_mode orbit-3x3 ;;
            5) activate_pixel_shift_mode linear-horizontal ;;
            6) activate_pixel_shift_mode linear-vertical ;;
            7) hyproled off ;;
        esac
    else
        case "$choice" in
            0)
                if [[ "$mask_enabled" == true ]]; then
                    if [[ "$pixel_shift" == true ]]; then
                        hyproled --no-mask
                    else
                        hyproled off
                    fi
                else
                    hyproled --mask
                fi
                ;;
            1) hyproled -s ;;
            2) activate_mask_mode 1 ;;
            3) activate_mask_mode 2 ;;
            4) activate_mask_mode 3 ;;
            5)
                if [[ "$brightness_compensation" == true ]]; then
                    hyproled --no-brightness-compensation
                else
                    hyproled --brightness-compensation
                fi
                ;;
            6) hyproled off ;;
        esac
    fi
    exit 0
done
