#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES="${NIXOS_CONTROL_DOTFILES:-${HOME}/dotfiles}"
SYSTEM_PROFILE="${NIXOS_CONTROL_SYSTEM_PROFILE:-/nix/var/nix/profiles/system}"
THEME_FILE="${NIXOS_CONTROL_ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/nixos-control.rasi}"
SCRIPT_PATH="${NIXOS_CONTROL_SCRIPT_PATH:-$0}"
PAGE="${NIXOS_CONTROL_PAGE:-menu}"
NOTICE="${NIXOS_CONTROL_NOTICE:-}"

if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
    PID_FILE="${XDG_RUNTIME_DIR}/nixos-control-center-rofi.pid"
else
    mkdir -p "${HOME}/.cache"
    PID_FILE="${HOME}/.cache/nixos-control-center-rofi.pid"
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nixos-control-center"
ROFI_LOG="${STATE_DIR}/rofi.log"
HARDWARE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nixos-control-center"
HARDWARE_CACHE_FILE="${HARDWARE_CACHE_DIR}/hardware.tsv"

escape_markup() {
    local value="${1:-}"
    value="${value//&/\&amp;}"
    value="${value//</\&lt;}"
    value="${value//>/\&gt;}"
    value="${value//\"/\&quot;}"
    printf '%s' "$value"
}

emit_static() {
    printf '%s\0nonselectable\x1ftrue\n' "$1"
}

emit_heading() {
    emit_static "<b>$1</b>"
}

emit_info() {
    local label="$1" value="$2" line
    value="$(escape_markup "$value")"
    printf -v line '  %-17s  %s' "$label" "$value"
    emit_static "$line"
}

emit_button() {
    local text="$1" info="$2" meta="${3:-}"
    printf '%s\0info\x1f%s\x1fmeta\x1f%s\x1factive\x1ftrue\n' \
        "$text" "$info" "$meta"
}

get_generation() {
    local target
    target="$(readlink -- "$SYSTEM_PROFILE" 2>/dev/null || true)"
    if [[ "$target" =~ system-([0-9]+)-link ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

resolve_generation_commit() {
    local generation="$1" link store_name short tag commit
    link="${SYSTEM_PROFILE}-${generation}-link"
    [[ -e "$link" ]] || return 1

    store_name="$(basename -- "$(readlink -f -- "$link" 2>/dev/null || true)")"
    if [[ "$store_name" =~ git-([[:xdigit:]]{7,40})-v ]]; then
        short="${BASH_REMATCH[1]}"
        commit="$(git -C "$DOTFILES" rev-parse --verify --quiet "${short}^{commit}" 2>/dev/null || true)"
        if [[ -n "$commit" ]]; then
            printf '%s' "$commit"
            return 0
        fi
    fi

    # Older or externally built generations may not expose a resolvable label.
    # The existing nixapply helper tags successful switch/boot generations.
    for tag in "gen-${generation}" "gen-${generation}-exp"; do
        commit="$(git -C "$DOTFILES" rev-parse --verify --quiet "refs/tags/${tag}^{commit}" 2>/dev/null || true)"
        if [[ -n "$commit" ]]; then
            printf '%s' "$commit"
            return 0
        fi
    done

    return 1
}

get_nixpkgs_revision() {
    local commit="$1" lock_json input_node revision
    [[ -n "$commit" ]] || return 1

    lock_json="$(git -C "$DOTFILES" show "${commit}:flake.lock" 2>/dev/null)" || return 1
    input_node="$(jq -r '
        .nodes.root.inputs.nixpkgs
        | if type == "array" then .[0] else . end
        // empty
    ' <<<"$lock_json" 2>/dev/null || true)"
    [[ -n "$input_node" && "$input_node" != "null" ]] || return 1

    revision="$(jq -r --arg node "$input_node" '.nodes[$node].locked.rev // empty' <<<"$lock_json" 2>/dev/null || true)"
    [[ -n "$revision" && "$revision" != "null" ]] || return 1
    printf '%s' "$revision"
}

get_short_commit() {
    local commit="$1"
    [[ -n "$commit" ]] || return 1
    git -C "$DOTFILES" rev-parse --short=8 "$commit" 2>/dev/null
}

get_battery_summary() {
    local battery capacity status
    for battery in /sys/class/power_supply/BAT*; do
        [[ -r "$battery/capacity" ]] || continue
        IFS= read -r capacity < "$battery/capacity" || capacity="?"
        if [[ -r "$battery/status" ]]; then
            IFS= read -r status < "$battery/status" || status="Unknown"
        else
            status="Unknown"
        fi
        printf '%s%% · %s' "$capacity" "$status"
        return 0
    done
    printf 'Not detected'
}

get_power_profiles() {
    local output line profile
    local -a profiles=()
    output="$(powerprofilesctl list 2>/dev/null || true)"

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line#\* }"
        [[ "$line" == *: ]] || continue
        profile="${line%:}"
        [[ "$profile" =~ ^[[:alnum:]_-]+$ ]] || continue
        profiles+=("$profile")
    done <<< "$output"

    printf '%s\n' "${profiles[@]}"
}

can_hibernate() {
    local result
    result="$(loginctl can-hibernate 2>/dev/null || true)"
    [[ "$result" == "yes" ]]
}

get_device_model() {
    local vendor model
    vendor="$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || true)"
    model="$(cat /sys/devices/virtual/dmi/id/product_version 2>/dev/null || true)"
    if [[ -z "$model" || "$model" == "None" || "$model" == "Default string" ]]; then
        model="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || true)"
    fi
    printf '%s' "${vendor:+${vendor} }${model:-Unknown device}"
}

get_cpu_summary() {
    local model topology
    model="$(awk -F ': ' '/^model name[[:space:]]*:/ { print $2; exit }' /proc/cpuinfo 2>/dev/null)"
    topology="$(lscpu 2>/dev/null | awk -F: '
        /^Core\(s\) per socket:/ { gsub(/[[:space:]]/, "", $2); cores = $2 }
        /^Socket\(s\):/ { gsub(/[[:space:]]/, "", $2); sockets = $2 }
        /^CPU\(s\):/ { gsub(/[[:space:]]/, "", $2); threads = $2 }
        END {
            if (cores != "" && sockets != "" && threads != "") {
                printf "%d cores / %d threads", cores * sockets, threads
            } else if (threads != "") {
                printf "%s threads", threads
            } else {
                printf "topology unavailable"
            }
        }
    ')"
    printf '%s · %s' "${model:-Unknown processor}" "$topology"
}

get_gpu_summary() {
    lspci -nn 2>/dev/null | awk -F ': ' '
        /VGA compatible controller|3D controller|Display controller/ {
            name = $2
            sub(/ \[[[:xdigit:]]{4}:[[:xdigit:]]{4}\].*$/, "", name)
            sub(/ \(rev [^)]+\)$/, "", name)
            gsub(/[[:space:]]+$/, "", name)
            print name
        }
    '
}

get_memory_summary() {
    awk -v total_kib="${1:-}" '
        /^MemTotal:/ { total = $2 }
        /^MemAvailable:/ { available = $2 }
        END {
            if (total_kib ~ /^[0-9]+$/) total = total_kib
            if (total > 0 && available > 0) {
                printf "%.1f GiB installed · %.1f GiB available", total / 1048576, available / 1048576
            } else {
                print "Unavailable"
            }
        }
    ' /proc/meminfo
}

get_storage_summary() {
    local storage
    storage="$(df -hP / 2>/dev/null | awk 'NR == 2 { printf "%s free / %s total (%s used)", $4, $2, $5 }')"
    printf '%s' "${storage:-Unavailable}"
}

get_display_summary() {
    local display
    if command -v hyprctl >/dev/null 2>&1; then
        display="$(hyprctl monitors -j 2>/dev/null | jq -r '
            [.[] | "\(.name): \(.width)x\(.height) @ \(.refreshRate) Hz"]
            | join(" · ")
        ' 2>/dev/null || true)"
    fi
    printf '%s' "${display:-Unavailable}"
}

get_memory_total_kib() {
    awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo
}

read_hardware_cache_field() {
    local key="$1"
    awk -F '\t' -v key="$key" '
        $1 == key {
            sub(/^[^\t]*\t/, "")
            print
            exit
        }
    ' "$HARDWARE_CACHE_FILE"
}

load_hardware_cache() {
    local boot_id cached_boot temp gpu
    local -a current_gpus=()

    HARDWARE_DEVICE=""
    HARDWARE_CPU=""
    HARDWARE_MEMORY_TOTAL_KIB=""
    HARDWARE_GPUS=()

    boot_id="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)"
    if [[ -z "$boot_id" ]]; then
        HARDWARE_DEVICE="$(get_device_model)"
        HARDWARE_CPU="$(get_cpu_summary)"
        HARDWARE_MEMORY_TOTAL_KIB="$(get_memory_total_kib)"
        while IFS= read -r gpu; do
            [[ -n "$gpu" ]] && current_gpus+=("$gpu")
        done < <(get_gpu_summary)
        HARDWARE_GPUS=("${current_gpus[@]}")
        return 0
    fi

    mkdir -p -- "$HARDWARE_CACHE_DIR"
    chmod 700 -- "$HARDWARE_CACHE_DIR"
    cached_boot=""
    if [[ -r "$HARDWARE_CACHE_FILE" ]]; then
        cached_boot="$(read_hardware_cache_field boot_id)"
    fi

    if [[ "$cached_boot" != "$boot_id" ]]; then
        temp="$(mktemp "${HARDWARE_CACHE_FILE}.XXXXXX")"
        {
            printf 'boot_id\t%s\n' "$boot_id"
            printf 'device\t%s\n' "$(get_device_model)"
            printf 'cpu\t%s\n' "$(get_cpu_summary)"
            printf 'memory_total_kib\t%s\n' "$(get_memory_total_kib)"
            while IFS= read -r gpu; do
                [[ -n "$gpu" ]] && printf 'gpu\t%s\n' "$gpu"
            done < <(get_gpu_summary)
        } > "$temp"
        chmod 600 -- "$temp"
        mv -f -- "$temp" "$HARDWARE_CACHE_FILE"
    fi

    HARDWARE_DEVICE="$(read_hardware_cache_field device)"
    HARDWARE_CPU="$(read_hardware_cache_field cpu)"
    HARDWARE_MEMORY_TOTAL_KIB="$(read_hardware_cache_field memory_total_kib)"
    mapfile -t HARDWARE_GPUS < <(
        awk -F '\t' '$1 == "gpu" { sub(/^[^\t]*\t/, ""); print }' "$HARDWARE_CACHE_FILE"
    )
}

theme_override() {
    case "$1" in
        menu)
            cat <<'RASI'
window { width: 390px; }
listview { lines: 5; }
mainbox { children: [ "inputbar", "listview" ]; }
RASI
            ;;
        overview)
            cat <<'RASI'
window { width: 980px; }
listview { lines: 20; }
mainbox { children: [ "inputbar", "message", "listview" ]; }
RASI
            ;;
        generations)
            cat <<'RASI'
window { width: 1240px; }
listview { lines: 24; }
mainbox { children: [ "inputbar", "message", "listview" ]; }
RASI
            ;;
        power)
            cat <<'RASI'
window { width: 650px; }
listview { lines: 12; }
mainbox { children: [ "inputbar", "message", "listview" ]; }
RASI
            ;;
        dotfiles)
            cat <<'RASI'
window { width: 780px; }
listview { lines: 11; }
mainbox { children: [ "inputbar", "message", "listview" ]; }
RASI
            ;;
        actions)
            cat <<'RASI'
window { width: 620px; }
listview { lines: 13; }
mainbox { children: [ "inputbar", "message", "listview" ]; }
RASI
            ;;
        confirm-*)
            cat <<'RASI'
window { width: 470px; }
listview { lines: 4; }
mainbox { children: [ "inputbar", "message", "listview" ]; }
RASI
            ;;
        *)
            cat <<'RASI'
window { width: 390px; }
listview { lines: 5; }
mainbox { children: [ "inputbar", "listview" ]; }
RASI
            ;;
    esac
}

prepare_rofi_log() {
    local size
    mkdir -p -- "$STATE_DIR"
    chmod 700 -- "$STATE_DIR"
    touch -- "$ROFI_LOG"
    chmod 600 -- "$ROFI_LOG"
    size="$(stat -c %s "$ROFI_LOG" 2>/dev/null || printf '0')"
    if [[ "$size" =~ ^[0-9]+$ ]] && ((size > 524288)); then
        tail -c 262144 "$ROFI_LOG" > "${ROFI_LOG}.tmp"
        chmod 600 -- "${ROFI_LOG}.tmp"
        mv -f -- "${ROFI_LOG}.tmp" "$ROFI_LOG"
    fi
}

open_window() {
    local page="$1" notice="${2:-}" override
    override="$(theme_override "$page")"

    # Replace the current Rofi process synchronously. Returning an empty result
    # from Script Mode closes the old window, so a detached launcher is racy.
    prepare_rofi_log
    printf '%s page=%s\n' "$(date --iso-8601=seconds)" "$page" >> "$ROFI_LOG"
    exec env \
        NIXOS_CONTROL_PAGE="$page" \
        NIXOS_CONTROL_NOTICE="$notice" \
        rofi \
            -replace \
            -pid "$PID_FILE" \
            -show nixos-control \
            -modi "nixos-control:${SCRIPT_PATH}" \
            -theme "$THEME_FILE" \
            -theme-str "$override" \
            -no-sort \
            </dev/null >/dev/null 2>>"$ROFI_LOG"
}

launch_kitty() {
    local title="$1"
    shift

    if ! command -v kitty >/dev/null 2>&1; then
        open_window actions "Kitty is not available; the action was not started."
    fi

    kitty --title "$title" "$@" </dev/null >/dev/null 2>&1 &
    disown "$!" 2>/dev/null || true
    exit 0
}

launch_nixapply() {
    local action="$1"
    if ! command -v nixapply >/dev/null 2>&1; then
        open_window actions "nixapply is not available; the action was not started."
    fi
    launch_kitty "NixOS Control · ${action}" --hold nixapply "$action"
}

launch_yazi() {
    if ! command -v yazi >/dev/null 2>&1; then
        open_window dotfiles "Yazi is not available."
    fi
    launch_kitty "Dotfiles · Yazi" --class yazi -- yazi "$DOTFILES"
}

run_system_power_action() {
    local action="$1" status=0

    if [[ "$action" == "hibernate" ]] && ! can_hibernate; then
        open_window actions "Hibernate is no longer available; no action was taken."
    fi

    case "$action" in
        reboot) systemctl reboot || status=$? ;;
        poweroff) systemctl poweroff || status=$? ;;
        hibernate) systemctl hibernate || status=$? ;;
        *) return 1 ;;
    esac

    if ((status == 0)); then
        exit 0
    fi

    open_window actions "${action^} request failed (exit ${status})."
}

render_menu() {
    printf '\0prompt\x1fNixOS Control\n'
    printf '\0markup-rows\x1ftrue\n'
    printf '\0no-custom\x1ftrue\n'

    emit_button "Overview" "open:overview" "system hardware processor graphics memory"
    emit_button "Generations" "open:generations" "history commit nixpkgs revision"
    emit_button "Power" "open:power" "battery energy profiles"
    emit_button "Dotfiles" "open:dotfiles" "repository git yazi files"
    emit_button "Actions" "open:actions" "build activate switch boot reboot shutdown hibernate"
}

render_overview() {
    local device cpu memory storage display os_version kernel architecture uptime gpu_index gpu_label
    local generation commit nixpkgs

    load_hardware_cache
    device="$HARDWARE_DEVICE"
    cpu="$HARDWARE_CPU"
    memory="$(get_memory_summary "$HARDWARE_MEMORY_TOTAL_KIB")"
    storage="$(get_storage_summary)"
    display="$(get_display_summary)"
    os_version="$(nixos-version 2>/dev/null || printf 'NixOS')"
    kernel="$(uname -r 2>/dev/null || printf 'Unavailable')"
    architecture="$(uname -m 2>/dev/null || printf 'Unavailable')"
    uptime="$(uptime -p 2>/dev/null || printf 'Unavailable')"
    generation="$(get_generation)"
    commit="$(resolve_generation_commit "$generation" 2>/dev/null || true)"
    nixpkgs="$(get_nixpkgs_revision "$commit" 2>/dev/null || true)"

    emit_heading "HARDWARE"
    emit_info "Device" "$device"
    emit_info "Processor" "$cpu"
    if ((${#HARDWARE_GPUS[@]} == 0)); then
        emit_info "Graphics" "Unavailable"
    else
        for ((gpu_index = 0; gpu_index < ${#HARDWARE_GPUS[@]}; gpu_index++)); do
            gpu_label="Graphics"
            if ((${#HARDWARE_GPUS[@]} > 1)); then
                gpu_label="Graphics $((gpu_index + 1))"
            fi
            emit_info "$gpu_label" "${HARDWARE_GPUS[$gpu_index]}"
        done
    fi
    emit_info "Memory" "$memory"
    emit_info "Storage" "$storage"
    emit_info "Display" "$display"
    emit_heading "SYSTEM"
    emit_info "Operating system" "$os_version"
    emit_info "Architecture" "$architecture"
    emit_info "Kernel" "$kernel"
    emit_info "Uptime" "$uptime"
    emit_heading "ACTIVE GENERATION"
    emit_info "Generation" "${generation:--}"
    emit_info "System commit" "${commit:--}"
    emit_info "nixpkgs rev" "${nixpkgs:--}"
    emit_button "← Control Center" "open:menu" "back main menu"
}

render_generations() {
    local generations number date current commit short nixpkgs state line
    generations="$(nix-env --list-generations --profile "$SYSTEM_PROFILE" 2>/dev/null || true)"

    emit_heading "SYSTEM GENERATIONS"
    printf -v line '%-5s %-10s %-8s %-40s %-8s' "GEN" "DATE" "COMMIT" "NIXPKGS REV" "STATE"
    emit_static "<b>${line}</b>"

    if [[ -z "$generations" ]]; then
        emit_static "  Generation information is unavailable."
    else
        while IFS=$'\t' read -r number date current; do
            [[ "$number" =~ ^[0-9]+$ ]] || continue
            commit="$(resolve_generation_commit "$number" 2>/dev/null || true)"
            short="$(get_short_commit "$commit" 2>/dev/null || printf '-')"
            nixpkgs="$(get_nixpkgs_revision "$commit" 2>/dev/null || printf '-')"
            state=""
            [[ "$current" == "1" ]] && state="CURRENT"
            printf -v line '%-5s %-10s %-8s %-40s %-8s' "$number" "$date" "$short" "$nixpkgs" "$state"
            line="$(escape_markup "$line")"
            if [[ "$current" == "1" ]]; then
                emit_static "<b>${line}</b>"
            else
                emit_static "$line"
            fi
        done < <(
            awk '$1 ~ /^[0-9]+$/ { print $1 "\t" $2 "\t" ($0 ~ /\(current\)/ ? "1" : "0") }' <<< "$generations" \
                | sort -rn -k1,1
        )
    fi

    emit_button "← Control Center" "open:menu" "back main menu"
}

render_power() {
    local current battery profiles profile label
    current="$(powerprofilesctl get 2>/dev/null || printf 'Unavailable')"
    battery="$(get_battery_summary)"
    profiles="$(get_power_profiles)"

    emit_heading "POWER STATUS"
    emit_info "Active profile" "$current"
    emit_info "Battery" "$battery"
    emit_heading "SELECT PROFILE"

    if [[ -z "$profiles" ]]; then
        emit_static "  power-profiles-daemon is unavailable."
    else
        while IFS= read -r profile; do
            [[ -n "$profile" ]] || continue
            label="$profile"
            [[ "$profile" == "$current" ]] && label="${profile}  · current"
            emit_button "$label" "power:set:${profile}" "${profile} power profile"
        done <<< "$profiles"
    fi

    emit_button "← Control Center" "open:menu" "back main menu"
}

render_dotfiles() {
    local branch head state changed
    if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        branch="$(git -C "$DOTFILES" branch --show-current 2>/dev/null || printf 'Detached')"
        head="$(git -C "$DOTFILES" rev-parse --short=12 HEAD 2>/dev/null || printf 'Unknown')"
        changed="$(git -C "$DOTFILES" status --porcelain 2>/dev/null || true)"
        state="Clean"
        [[ -n "$changed" ]] && state="Dirty"
    else
        branch="Unavailable"
        head="Unavailable"
        state="Unavailable"
    fi

    emit_heading "DOTFILES REPOSITORY"
    emit_info "Path" "$DOTFILES"
    emit_info "Branch" "$branch"
    emit_info "HEAD" "$head"
    emit_info "Working tree" "$state"
    emit_button "Open dotfiles in Yazi" "browse:dotfiles" "browse repository files"
    emit_button "← Control Center" "open:menu" "back main menu"
}

render_actions() {
    emit_heading "NIXOS CONFIGURATION"
    emit_button "Build configuration" "run:build" "build compile generation"
    emit_button "Dry activate" "run:dry-activate" "preview activation"
    emit_button "Switch immediately" "run:switch" "activate system now"
    emit_button "Apply on next boot" "run:boot" "boot generation"
    emit_button "Test until reboot" "run:test" "temporary activation"
    emit_heading "SYSTEM POWER"
    emit_button "Reboot" "confirm:reboot" "restart system"
    emit_button "Power off" "confirm:poweroff" "shutdown system"
    if can_hibernate; then
        emit_button "Hibernate" "confirm:hibernate" "suspend to disk"
    fi
    emit_button "← Control Center" "open:menu" "back main menu"
}

render_confirmation() {
    local action label
    case "$PAGE" in
        confirm-reboot)
            action="reboot"
            label="Restart the system now?"
            ;;
        confirm-poweroff)
            action="poweroff"
            label="Power off the system now?"
            ;;
        confirm-hibernate)
            action="hibernate"
            label="Hibernate the system now?"
            ;;
        *)
            open_window actions
            ;;
    esac

    emit_static "$label"
    emit_button "Yes, continue" "execute:${action}" "confirm ${action}"
    emit_button "Cancel" "open:actions" "cancel back"
}

render_page() {
    local prompt
    case "$PAGE" in
        menu) render_menu; return ;;
        overview) prompt="System information" ;;
        generations) prompt="System generations" ;;
        power) prompt="Power profiles" ;;
        dotfiles) prompt="Dotfiles" ;;
        actions) prompt="System actions" ;;
        confirm-reboot|confirm-poweroff|confirm-hibernate) prompt="Confirm action" ;;
        *) open_window menu ;;
    esac

    printf '\0prompt\x1f%s\n' "$prompt"
    printf '\0markup-rows\x1ftrue\n'
    printf '\0no-custom\x1ftrue\n'
    if [[ -n "$NOTICE" ]]; then
        printf '\0message\x1f%s\n' "$(escape_markup "$NOTICE")"
    fi

    case "$PAGE" in
        overview) render_overview ;;
        generations) render_generations ;;
        power) render_power ;;
        dotfiles) render_dotfiles ;;
        actions) render_actions ;;
        confirm-*) render_confirmation ;;
    esac
}

handle_selection() {
    local selection="${ROFI_INFO:-}" profile

    case "$selection" in
        open:menu|open:overview|open:generations|open:power|open:dotfiles|open:actions)
            open_window "${selection#open:}"
            ;;
        power:set:*)
            profile="${selection#power:set:}"
            if [[ "$profile" =~ ^[[:alnum:]_-]+$ ]] && powerprofilesctl set "$profile" >/dev/null 2>&1; then
                open_window power
            else
                open_window power "Could not activate power profile '${profile}'."
            fi
            ;;
        browse:dotfiles)
            launch_yazi
            ;;
        run:build|run:dry-activate|run:switch|run:boot|run:test)
            launch_nixapply "${selection#run:}"
            ;;
        confirm:reboot|confirm:poweroff|confirm:hibernate)
            open_window "confirm-${selection#confirm:}"
            ;;
        execute:reboot|execute:poweroff|execute:hibernate)
            run_system_power_action "${selection#execute:}"
            ;;
    esac
}

if [[ -z "${ROFI_RETV+x}" ]]; then
    export NIXOS_CONTROL_PAGE=menu
    prepare_rofi_log
    printf '%s page=menu\n' "$(date --iso-8601=seconds)" >> "$ROFI_LOG"
    exec rofi \
        -replace \
        -pid "$PID_FILE" \
        -show nixos-control \
        -modi "nixos-control:${SCRIPT_PATH}" \
        -theme "$THEME_FILE" \
        -theme-str "$(theme_override menu)" \
        -no-sort \
        </dev/null >/dev/null 2>>"$ROFI_LOG"
fi

if [[ "${ROFI_RETV:-0}" == "1" ]]; then
    handle_selection
fi

render_page
