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
        jq -r --arg fallback "$fallback" "($expression) // \$fallback" "$source_file"
    else
        printf '%s\n' "$fallback"
    fi
}

mask_enabled=$(read_setting 'if has("status") then (if .version >= 4 then .maskEnabled else true end) else .maskEnabled end' false)
pixel_shift=$(read_setting '.pixelShift' false)
pixel_shift_mode=$(read_setting 'if has("status") and .version < 5 and (.pixelShift // false) then "fixed" else .pixelShiftMode end' 'orbit-2x2')
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

emit_option() {
    local label="$1"
    local info="$2"
    local active="${3:-false}"

    if [[ "$active" == true ]]; then
        printf '%s\0info\x1f%s\x1factive\x1ftrue\n' "$label" "$info"
    else
        printf '%s\0info\x1f%s\n' "$label" "$info"
    fi
}

emit_option_for_key() {
    local label="$1"
    local info="$2"
    local active=false

    if [[ "$active_key" == "$info" ]]; then
        active=true
    fi

    emit_option "$label" "$info" "$active"
}

emit_menu() {
    local page="$1"
    local active_key=""

    printf '\0markup-rows\x1ftrue\n'
    printf '\0no-custom\x1ftrue\n'
    printf '\0use-hot-keys\x1ftrue\n'
    printf '\0data\x1f%s\n' "$page"

    if [[ "$page" == 0 ]]; then
        printf '\0prompt\x1fHyproled  /  Pixel Shift\n'
        printf '\0message\x1f→  Mask &amp; Brightness\n'

        if [[ "$pixel_shift" == true ]]; then
            pixel_shift_toggle='<b>Disable Pixel Shift</b>'
            case "$pixel_shift_mode" in
                fixed) active_key=pixel-fixed ;;
                orbit-2x2) active_key=pixel-orbit-2x2 ;;
                orbit-3x3) active_key=pixel-orbit-3x3 ;;
                linear-horizontal) active_key=pixel-linear-horizontal ;;
                linear-vertical) active_key=pixel-linear-vertical ;;
            esac
        else
            pixel_shift_toggle='<b>Enable Pixel Shift</b>'
        fi

        emit_option "$pixel_shift_toggle" pixel-toggle
        emit_option '<b>Advance all effects</b>' advance
        emit_option_for_key 'Fixed' pixel-fixed
        emit_option_for_key 'Orbit 2x2 (default)' pixel-orbit-2x2
        emit_option_for_key 'Orbit 3x3' pixel-orbit-3x3
        emit_option_for_key 'Linear horizontal' pixel-linear-horizontal
        emit_option_for_key 'Linear vertical' pixel-linear-vertical
        emit_option '<b>Disable all effects</b>' disable-all
    else
        printf '\0prompt\x1fHyproled  /  Mask & Brightness\n'
        printf '\0message\x1f←  Pixel Shift\n'

        if [[ "$mask_enabled" == true ]]; then
            mask_toggle='<b>Disable mask</b>'
            active_key="mask-${off_pixels}"
        else
            mask_toggle='<b>Enable mask</b>'
        fi

        if [[ "$brightness_compensation" == true ]]; then
            brightness_toggle='Disable brightness compensation'
        else
            brightness_toggle='Enable brightness compensation'
        fi

        emit_option "$mask_toggle" mask-toggle
        emit_option '<b>Advance all effects</b>' advance
        emit_option_for_key '1 pixel disabled' mask-1
        emit_option_for_key '2 pixels disabled' mask-2
        emit_option_for_key '3 pixels disabled' mask-3
        emit_option "$brightness_toggle" brightness-toggle "$brightness_compensation"
        emit_option '<b>Disable all effects</b>' disable-all
    fi
}

# Keep one Rofi process alive while changing pages. Rofi script mode reruns this
# script with ROFI_RETV=10/11 for the configured custom keybindings.
if [[ -z "${ROFI_RETV+x}" ]]; then
    exec rofi \
        -show hyproled \
        -modi "hyproled:$0" \
        -i \
        -no-sort \
        -location 0 \
        -theme "$theme_file" \
        -kb-move-char-back Control+b \
        -kb-move-char-forward Control+f \
        -kb-custom-1 Right \
        -kb-custom-2 Left
fi

page="${ROFI_DATA:-0}"
case "${ROFI_RETV:-0}" in
    10) page=1 ;;
    11) page=0 ;;
    1)
        case "${ROFI_INFO:-}" in
            pixel-toggle)
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
            advance) hyproled -s ;;
            pixel-fixed) activate_pixel_shift_mode fixed ;;
            pixel-orbit-2x2) activate_pixel_shift_mode orbit-2x2 ;;
            pixel-orbit-3x3) activate_pixel_shift_mode orbit-3x3 ;;
            pixel-linear-horizontal) activate_pixel_shift_mode linear-horizontal ;;
            pixel-linear-vertical) activate_pixel_shift_mode linear-vertical ;;
            mask-toggle)
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
            mask-1) activate_mask_mode 1 ;;
            mask-2) activate_mask_mode 2 ;;
            mask-3) activate_mask_mode 3 ;;
            brightness-toggle)
                if [[ "$brightness_compensation" == true ]]; then
                    hyproled --no-brightness-compensation
                else
                    hyproled --brightness-compensation
                fi
                ;;
            disable-all) hyproled off ;;
            *) exit 0 ;;
        esac
        # Rofi script mode closes when the script returns no menu entries.
        exit 0
        ;;
    0) ;;
    *) exit 0 ;;
esac

case "$page" in
    0|1) ;;
    *) page=0 ;;
esac

emit_menu "$page"
