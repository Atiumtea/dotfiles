#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES="${NIXOS_CONTROL_DOTFILES:-${HOME}/dotfiles}"
SYSTEM_PROFILE="${NIXOS_CONTROL_SYSTEM_PROFILE:-/nix/var/nix/profiles/system}"
PAGE="${ROFI_DATA:-overview}"
NOTICE=""

escape_markup() {
    local value="${1:-}"
    value="${value//&/\&amp;}"
    value="${value//</\&lt;}"
    value="${value//>/\&gt;}"
    value="${value//\"/\&quot;}"
    printf '%s' "$value"
}

short_value() {
    local value="${1:--}" limit="${2:-24}"
    if ((${#value} > limit)); then
        printf '%s…' "${value:0:limit-1}"
    else
        printf '%s' "$value"
    fi
}

emit_static() {
    printf '%s\0nonselectable\x1ftrue\n' "$1"
}

emit_permanent() {
    printf '%s\0nonselectable\x1ftrue\x1fpermanent\x1ftrue\n' "$1"
}

emit_row() {
    local text="$1" info="$2" meta="${3:-}"
    if [[ -n "$meta" ]]; then
        printf '%s\0info\x1f%s\x1fmeta\x1f%s\n' "$text" "$info" "$meta"
    else
        printf '%s\0info\x1f%s\n' "$text" "$info"
    fi
}

emit_section() {
    emit_permanent "<b>  $1</b>"
}

emit_pair() {
    local label="$1" value line
    value="$(escape_markup "${2:--}")"
    printf -v line '  %-17s  %s' "$label" "$value"
    emit_static "$line"
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

can_hibernate() {
    local result
    result="$(loginctl can-hibernate 2>/dev/null || true)"
    [[ "$result" == "yes" ]]
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

launch_kitty() {
    local title="$1"
    shift

    if ! command -v kitty >/dev/null 2>&1; then
        NOTICE="Kitty is not available in PATH."
        return 1
    fi

    kitty --title "$title" "$@" </dev/null >/dev/null 2>&1 &
    disown "$!" 2>/dev/null || true
    exit 0
}

launch_nixapply() {
    local action="$1"

    if ! command -v nixapply >/dev/null 2>&1; then
        NOTICE="nixapply is not available in PATH; rebuild was not started."
        return 1
    fi

    launch_kitty "NixOS Control · ${action}" --hold nixapply "$action"
}

launch_yazi() {
    if ! command -v yazi >/dev/null 2>&1; then
        NOTICE="Yazi is not available in PATH."
        return 1
    fi

    launch_kitty "Dotfiles · Yazi" --class yazi -- yazi "$DOTFILES"
}

run_power_action() {
    local action="$1" status=0

    if [[ "$action" == "hibernate" ]] && ! can_hibernate; then
        NOTICE="Hibernate is not currently available; no action was taken."
        PAGE="actions"
        return 1
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

    NOTICE="${action^} request failed (exit ${status})."
    PAGE="actions"
    return 1
}

render_overview() {
    local host os_version kernel generation commit nixpkgs repo_branch repo_head repo_state uptime nix_space
    host="$(hostname 2>/dev/null || printf 'Unknown')"
    os_version="$(nixos-version 2>/dev/null || printf 'Unknown')"
    kernel="$(uname -r 2>/dev/null || printf 'Unknown')"
    generation="$(get_generation)"
    commit="$(resolve_generation_commit "$generation" 2>/dev/null || true)"
    nixpkgs="$(get_nixpkgs_revision "$commit" 2>/dev/null || true)"
    if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repo_branch="$(git -C "$DOTFILES" branch --show-current 2>/dev/null || printf 'Detached')"
        repo_head="$(git -C "$DOTFILES" rev-parse --short=8 HEAD 2>/dev/null || printf 'Unknown')"
        if [[ -n "$(git -C "$DOTFILES" status --porcelain 2>/dev/null || true)" ]]; then
            repo_state="Dirty"
        else
            repo_state="Clean"
        fi
    else
        repo_branch="Unavailable"
        repo_head="Unavailable"
        repo_state="Unavailable"
    fi
    uptime="$(uptime -p 2>/dev/null || printf 'Unknown')"
    nix_space="$(df -hP /nix 2>/dev/null | awk 'NR == 2 { printf "%s free / %s total", $4, $2 }' || true)"
    [[ -n "$nix_space" ]] || nix_space="Unavailable"

    emit_section "SYSTEM"
    emit_pair "Host" "$host"
    emit_pair "NixOS" "$os_version"
    emit_pair "Kernel" "$kernel"
    emit_pair "Uptime" "$uptime"
    emit_pair "/nix" "$nix_space"
    emit_section "ACTIVE GENERATION"
    emit_pair "Generation" "${generation:--}"
    emit_pair "System commit" "$(get_short_commit "$commit" 2>/dev/null || printf '-')"
    emit_pair "nixpkgs rev" "$(short_value "${nixpkgs:--}" 12)"
    emit_section "DOTFILES CHECKOUT"
    emit_pair "Branch" "$repo_branch"
    emit_pair "HEAD" "$repo_head"
    emit_pair "Working tree" "$repo_state"
}

render_generations() {
    local generations number date time current commit short nixpkgs state line
    generations="$(nix-env --list-generations --profile "$SYSTEM_PROFILE" 2>/dev/null || true)"

    emit_section "SYSTEM GENERATIONS"
    printf -v line '%-5s %-10s %-8s %-40s %-8s' "GEN" "DATE" "COMMIT" "NIXPKGS REV" "STATE"
    emit_permanent "<b>${line}</b>"

    if [[ -z "$generations" ]]; then
        emit_static "  Generation information is unavailable."
        return
    fi

    while IFS=$'\t' read -r number date time current; do
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
        awk '$1 ~ /^[0-9]+$/ { print $1 "\t" $2 "\t" $3 "\t" ($0 ~ /\(current\)/ ? "1" : "0") }' <<< "$generations" \
            | sort -rn -k1,1
    )
}

render_power() {
    local current battery profiles profile marker
    current="$(powerprofilesctl get 2>/dev/null || printf 'Unavailable')"
    battery="$(get_battery_summary)"
    profiles="$(get_power_profiles)"

    emit_section "POWER STATUS"
    emit_pair "Active profile" "$current"
    emit_pair "Battery" "$battery"
    emit_section "AVAILABLE PROFILES"

    if [[ -z "$profiles" ]]; then
        emit_static "  power-profiles-daemon is unavailable."
        return
    fi

    while IFS= read -r profile; do
        [[ -n "$profile" ]] || continue
        marker="  "
        [[ "$profile" == "$current" ]] && marker="* "
        emit_row "${marker}${profile}" "power:set:${profile}" "${profile} power profile"
    done <<< "$profiles"
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

    emit_section "DOTFILES REPOSITORY"
    emit_pair "Path" "$DOTFILES"
    emit_pair "Branch" "$branch"
    emit_pair "HEAD" "$head"
    emit_pair "Working tree" "$state"
    emit_section "BROWSE"
    emit_row "Open dotfiles in Yazi" "browse:dotfiles" "file manager tree repository"
}

render_actions() {
    emit_section "NIXOS CONFIGURATION"
    emit_row "Build configuration" "run:build" "build compile generation"
    emit_row "Dry activate" "run:dry-activate" "preview activation"
    emit_row "Switch immediately" "run:switch" "activate system now"
    emit_row "Apply on next boot" "run:boot" "boot generation"
    emit_row "Test until reboot" "run:test" "temporary activation"
    emit_section "SYSTEM POWER"
    emit_row "Reboot" "confirm:reboot" "restart"
    emit_row "Power off" "confirm:poweroff" "shutdown"
    if can_hibernate; then
        emit_row "Hibernate" "confirm:hibernate" "suspend to disk"
    else
        emit_static "  Hibernate is unavailable on this system."
    fi
}

render_confirmation() {
    local action label
    case "$PAGE" in
        confirm-reboot) action="reboot"; label="Restart the system now?" ;;
        confirm-poweroff) action="poweroff"; label="Power off the system now?" ;;
        confirm-hibernate) action="hibernate"; label="Hibernate the system now?" ;;
        *) PAGE="actions"; render_actions; return ;;
    esac

    emit_section "CONFIRM SYSTEM ACTION"
    emit_static "  ${label}"
    emit_row "Yes, continue" "execute:${action}" "confirm ${action}"
    emit_row "Cancel" "page:actions" "back"
}

render_navigation() {
    emit_section "PAGES"
    emit_row "Overview" "page:overview" "system summary"
    emit_row "Generations" "page:generations" "history commits nixpkgs"
    emit_row "Power" "page:power" "power profiles battery"
    emit_row "Dotfiles" "page:dotfiles" "git yazi file manager"
    emit_row "Actions" "page:actions" "build switch reboot shutdown"
}

render_page() {
    local prompt message
    case "$PAGE" in
        overview) prompt="NixOS / Overview" ;;
        generations) prompt="NixOS / Generations" ;;
        power) prompt="NixOS / Power" ;;
        dotfiles) prompt="NixOS / Dotfiles" ;;
        actions) prompt="NixOS / Actions" ;;
        confirm-*) prompt="NixOS / Confirm" ;;
        *) PAGE="overview"; prompt="NixOS / Overview" ;;
    esac

    message="${NOTICE:-Type to filter · Select a row · Esc to close}"
    printf '\0prompt\x1f%s\n' "$prompt"
    printf '\0message\x1f%s\n' "$(escape_markup "$message")"
    printf '\0markup-rows\x1ftrue\n'
    printf '\0no-custom\x1ftrue\n'
    printf '\0data\x1f%s\n' "$PAGE"

    case "$PAGE" in
        overview) render_overview ;;
        generations) render_generations ;;
        power) render_power ;;
        dotfiles) render_dotfiles ;;
        actions) render_actions ;;
        confirm-*) render_confirmation ;;
    esac

    render_navigation
}

handle_selection() {
    local selection="${ROFI_INFO:-}" profile
    case "$selection" in
        page:overview|page:generations|page:power|page:dotfiles|page:actions)
            PAGE="${selection#page:}"
            NOTICE=""
            ;;
        power:set:*)
            profile="${selection#power:set:}"
            if [[ "$profile" =~ ^[[:alnum:]_-]+$ ]] && powerprofilesctl set "$profile" >/dev/null 2>&1; then
                PAGE="power"
                NOTICE="Power profile changed to ${profile}."
            else
                PAGE="power"
                NOTICE="Could not activate power profile '${profile}'."
            fi
            ;;
        browse:dotfiles)
            launch_yazi || true
            ;;
        run:build|run:dry-activate|run:switch|run:boot|run:test)
            launch_nixapply "${selection#run:}" || true
            ;;
        confirm:reboot|confirm:poweroff|confirm:hibernate)
            PAGE="confirm-${selection#confirm:}"
            NOTICE=""
            ;;
        execute:reboot|execute:poweroff|execute:hibernate)
            run_power_action "${selection#execute:}" || true
            ;;
        page:*)
            PAGE="overview"
            ;;
    esac
}

if [[ -z "${ROFI_RETV:-}" ]]; then
    theme_file="${NIXOS_CONTROL_ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/nixos-control.rasi}"
    exec rofi \
        -show nixos-control \
        -modi "nixos-control:$0" \
        -theme "$theme_file" \
        -no-sort
fi

if [[ "${ROFI_RETV:-0}" == "1" ]]; then
    handle_selection
fi

render_page
