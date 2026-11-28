#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

VIDEO_BDF="${GPU_SWITCH_VIDEO_BDF:-0000:01:00.0}"
AUDIO_BDF="${GPU_SWITCH_AUDIO_BDF:-0000:01:00.1}"
DOMAIN="${GPU_SWITCH_DOMAIN:-win10}"
PCI_SYSFS=/sys/bus/pci/devices
LOCK_FILE=/run/lock/gpu-switch.lock

log() {
    printf '[gpu-switch] %s\n' "$*"
}

die() {
    printf '[gpu-switch] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage: gpu-switch <vm|host|status>

  vm      Bind the configured NVIDIA GPU and its audio function to vfio-pci.
  host    Return the GPU to nvidia and its audio function to snd_hda_intel.
  status  Show current drivers, driver overrides, NVIDIA modules and VM state.

Run 'gpu-switch vm' before starting the configured libvirt domain.
Run 'gpu-switch host' after the domain has completely shut down.
USAGE
}

require_root() {
    [[ "$EUID" -eq 0 ]] || die "Run as root: sudo gpu-switch $*"
}

validate_config() {
    [[ "$VIDEO_BDF" =~ ^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]] \
        || die "Invalid video PCI address: $VIDEO_BDF"
    [[ "$AUDIO_BDF" =~ ^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]] \
        || die "Invalid audio PCI address: $AUDIO_BDF"
    [[ "${VIDEO_BDF%.*}" == "${AUDIO_BDF%.*}" ]] \
        || die "Video and audio functions must belong to the same PCI slot"
    [[ "$VIDEO_BDF" != "$AUDIO_BDF" ]] || die "Video and audio PCI addresses must differ"
}

require_devices() {
    local bdf vendor
    for bdf in "$VIDEO_BDF" "$AUDIO_BDF"; do
        [[ -d "$PCI_SYSFS/$bdf" ]] || die "PCI device not found: $bdf"
        [[ -w "$PCI_SYSFS/$bdf/driver_override" ]] \
            || die "driver_override is unavailable for $bdf"
        vendor="$(<"$PCI_SYSFS/$bdf/vendor")"
        [[ "$vendor" == 0x10de ]] || die "$bdf is not an NVIDIA device (vendor=$vendor)"
    done
}

driver_of() {
    local link="$PCI_SYSFS/$1/driver"
    if [[ -L "$link" ]]; then
        basename "$(readlink -f "$link")"
    else
        printf 'unbound\n'
    fi
}

override_of() {
    local value
    value="$(<"$PCI_SYSFS/$1/driver_override")"
    [[ -n "$value" ]] || value=none
    printf '%s\n' "$value"
}

group_of() {
    local group_path
    group_path="$(readlink -f "$PCI_SYSFS/$1/iommu_group" 2>/dev/null || true)"
    if [[ -n "$group_path" && -d "$group_path" ]]; then
        basename "$group_path"
    else
        printf 'none\n'
    fi
}

vm_state() {
    local state
    if ! state="$(timeout --signal=TERM --kill-after=1s 5s \
        virsh -c qemu:///system domstate "$DOMAIN" 2>&1)"; then
        printf '%s\n' "$state" >&2
        return 1
    fi

    state="${state//$'\r'/}"
    state="${state,,}"
    while [[ "$state" == ' '* ]]; do state="${state# }"; done
    while [[ "$state" == *' ' ]]; do state="${state% }"; done
    printf '%s\n' "$state"
}

require_vm_off() {
    local state
    if ! state="$(vm_state)"; then
        die "Cannot query libvirt domain '$DOMAIN'; refusing to change PCI ownership"
    fi
    [[ "$state" == 'shut off' ]] \
        || die "Domain '$DOMAIN' is '$state'; switching is allowed only while it is shut off"
}

wait_for_driver() {
    local bdf="$1" expected="$2" attempt
    for ((attempt = 0; attempt < 50; attempt++)); do
        [[ "$(driver_of "$bdf")" == "$expected" ]] && return 0
        sleep 0.1
    done
    return 1
}

set_driver_override() {
    local bdf="$1" driver="$2"
    printf '%s\n' "$driver" > "$PCI_SYSFS/$bdf/driver_override" \
        || die "Cannot set driver_override='$driver' for $bdf"
}

clear_driver_override() {
    local bdf="$1"
    printf '\n' > "$PCI_SYSFS/$bdf/driver_override" \
        || die "Cannot clear driver_override for $bdf"
}

set_power_control() {
    local mode="$1" bdf control
    for bdf in "$VIDEO_BDF" "$AUDIO_BDF"; do
        control="$PCI_SYSFS/$bdf/power/control"
        [[ -e "$control" ]] || continue
        [[ -w "$control" ]] || die "Cannot change runtime power policy for $bdf"
        printf '%s\n' "$mode" > "$control" \
            || die "Cannot set power/control='$mode' for $bdf"
    done
}

unbind_device() {
    local bdf="$1" expected="$2" current
    current="$(driver_of "$bdf")"
    [[ "$current" == unbound ]] && return 0
    [[ "$current" == "$expected" ]] \
        || die "Refusing to unbind $bdf: expected '$expected', found '$current'"

    log "Unbinding $bdf from $current"
    printf '%s\n' "$bdf" > "$PCI_SYSFS/$bdf/driver/unbind" \
        || die "Kernel refused to unbind $bdf from $current"
    wait_for_driver "$bdf" unbound \
        || die "Timed out waiting for $bdf to become unbound"
}

bind_device() {
    local bdf="$1" driver="$2" current
    current="$(driver_of "$bdf")"
    [[ "$current" == "$driver" ]] && return 0
    [[ "$current" == unbound ]] \
        || die "Refusing to bind $bdf to '$driver': it is still bound to '$current'"

    set_driver_override "$bdf" "$driver"
    log "Binding $bdf to $driver"
    printf '%s\n' "$bdf" > /sys/bus/pci/drivers_probe \
        || die "PCI driver probe failed for $bdf"
    wait_for_driver "$bdf" "$driver" \
        || die "Timed out: $bdf is bound to '$(driver_of "$bdf")', expected '$driver'"
}

collect_gpu_nodes() {
    local node entry card_dir card_number
    GPU_NODES=()

    for node in /dev/nvidia* /dev/nvidia-caps/*; do
        [[ -c "$node" ]] && GPU_NODES+=("$node")
    done

    for entry in "$PCI_SYSFS/$VIDEO_BDF"/drm/*; do
        node="/dev/dri/${entry##*/}"
        [[ -e "$node" ]] && GPU_NODES+=("$node")
    done

    for card_dir in "$PCI_SYSFS/$AUDIO_BDF"/sound/card*; do
        card_number="${card_dir##*card}"
        for node in /dev/snd/*C"$card_number"*; do
            [[ -e "$node" ]] && GPU_NODES+=("$node")
        done
    done
}

require_fuser() {
    command -v fuser >/dev/null 2>&1 || die "fuser is missing (psmisc must be installed)"
}

check_no_gpu_users() {
    require_fuser
    collect_gpu_nodes
    ((${#GPU_NODES[@]} > 0)) || return 0

    if fuser -s "${GPU_NODES[@]}"; then
        log "Processes are using NVIDIA/DRM/HDMI-audio device nodes:"
        fuser -v "${GPU_NODES[@]}" 2>&1 || true
        die "Close applications using the NVIDIA GPU, then retry"
    fi
}

check_no_vfio_users() {
    require_fuser
    local bdf group node
    local -a nodes=()
    for bdf in "$VIDEO_BDF" "$AUDIO_BDF"; do
        group="$(group_of "$bdf")"
        [[ "$group" == none ]] && die "No IOMMU group found for $bdf"
        node="/dev/vfio/$group"
        [[ -e "$node" ]] && nodes+=("$node")
    done

    ((${#nodes[@]} > 0)) || return 0
    if fuser -s "${nodes[@]}"; then
        log "VFIO group is still open:"
        fuser -v "${nodes[@]}" 2>&1 || true
        die "A process still holds the VFIO group; ensure the VM has fully stopped"
    fi
}

check_iommu_group_members() {
    local bdf group_path member member_bdf member_driver
    for bdf in "$VIDEO_BDF" "$AUDIO_BDF"; do
        group_path="$(readlink -f "$PCI_SYSFS/$bdf/iommu_group" 2>/dev/null || true)"
        [[ -n "$group_path" && -d "$group_path/devices" ]] \
            || die "No IOMMU group is available for $bdf"

        for member in "$group_path"/devices/*; do
            [[ -e "$member" ]] || continue
            member_bdf="${member##*/}"
            [[ "$member_bdf" == "$VIDEO_BDF" || "$member_bdf" == "$AUDIO_BDF" ]] && continue
            member_driver="$(driver_of "$member_bdf")"
            case "$member_driver" in
                vfio-pci|unbound) ;;
                *) die "IOMMU group $group_path also contains $member_bdf bound to '$member_driver'; refusing unsafe passthrough" ;;
            esac
        done
    done
}

nvidia_stack_loaded() {
    local module
    for module in nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem; do
        [[ -d "/sys/module/$module" ]] && return 0
    done
    return 1
}

unload_nvidia_stack() {
    local module
    local modules=(nvidia_drm nvidia_modeset nvidia_uvm nvidia_peermem nvidia)

    for module in "${modules[@]}"; do
        [[ -d "/sys/module/$module" ]] || continue
        log "Unloading $module"
        modprobe -r "$module" \
            || die "Could not unload $module. No forced PCI reset/unbind was attempted; inspect GPU users and module references"
    done

    nvidia_stack_loaded && die "NVIDIA kernel modules are still loaded after removal"
}

verify_vfio() {
    local bdf group
    [[ "$(driver_of "$VIDEO_BDF")" == vfio-pci ]] \
        || die "Video device is not bound to vfio-pci"
    [[ "$(driver_of "$AUDIO_BDF")" == vfio-pci ]] \
        || die "Audio device is not bound to vfio-pci"

    udevadm settle --timeout=5 || die "udev did not settle after VFIO binding"
    for bdf in "$VIDEO_BDF" "$AUDIO_BDF"; do
        group="$(group_of "$bdf")"
        [[ -e "/dev/vfio/$group" ]] \
            || die "VFIO group device /dev/vfio/$group was not created"
    done

    # NixOS NVIDIA PRIME rules set power/control=auto on PCI bind events,
    # including a bind to vfio-pci. Keep the passed-through GPU awake.
    set_power_control on
}

switch_to_vm() {
    require_devices
    require_vm_off
    check_iommu_group_members

    if systemctl is-active --quiet nvidia-persistenced.service 2>/dev/null; then
        log "Stopping nvidia-persistenced"
        systemctl stop nvidia-persistenced.service \
            || die "Could not stop nvidia-persistenced.service"
    fi

    check_no_gpu_users
    modprobe vfio-pci || die "Could not load vfio-pci"

    # driver_override prevents NVIDIA from reclaiming the GPU after its module unloads.
    set_driver_override "$VIDEO_BDF" vfio-pci
    set_driver_override "$AUDIO_BDF" vfio-pci
    unload_nvidia_stack

    case "$(driver_of "$VIDEO_BDF")" in
        unbound|vfio-pci) ;;
        *) die "Unexpected video driver after NVIDIA unload: $(driver_of "$VIDEO_BDF")" ;;
    esac

    case "$(driver_of "$AUDIO_BDF")" in
        unbound|vfio-pci) ;;
        snd_hda_intel) unbind_device "$AUDIO_BDF" snd_hda_intel ;;
        *) die "Unexpected audio driver: $(driver_of "$AUDIO_BDF")" ;;
    esac

    bind_device "$VIDEO_BDF" vfio-pci
    bind_device "$AUDIO_BDF" vfio-pci
    verify_vfio

    clear_driver_override "$VIDEO_BDF"
    clear_driver_override "$AUDIO_BDF"
    log "GPU and HDMI audio are ready for VM '$DOMAIN' (both bound to vfio-pci)"
}

switch_to_host() {
    require_devices
    require_vm_off
    check_no_vfio_users

    set_driver_override "$VIDEO_BDF" nvidia
    set_driver_override "$AUDIO_BDF" snd_hda_intel

    modprobe nvidia || die "Could not load the NVIDIA kernel module"
    modprobe nvidia_modeset || die "Could not load nvidia_modeset"
    modprobe nvidia_uvm || die "Could not load nvidia_uvm"
    modprobe nvidia_drm || die "Could not load nvidia_drm"
    modprobe snd_hda_intel || die "Could not load snd_hda_intel"

    case "$(driver_of "$VIDEO_BDF")" in
        nvidia|unbound) ;;
        vfio-pci) unbind_device "$VIDEO_BDF" vfio-pci ;;
        *) die "Unexpected video driver: $(driver_of "$VIDEO_BDF")" ;;
    esac

    case "$(driver_of "$AUDIO_BDF")" in
        snd_hda_intel|unbound) ;;
        vfio-pci) unbind_device "$AUDIO_BDF" vfio-pci ;;
        *) die "Unexpected audio driver: $(driver_of "$AUDIO_BDF")" ;;
    esac

    bind_device "$VIDEO_BDF" nvidia
    bind_device "$AUDIO_BDF" snd_hda_intel
    udevadm settle --timeout=5 || die "udev did not settle after host binding"
    set_power_control auto

    clear_driver_override "$VIDEO_BDF"
    clear_driver_override "$AUDIO_BDF"
    log "GPU is back on the host (nvidia + snd_hda_intel)"
}

show_status() {
    local bdf group state module
    printf 'Domain: %s\n' "$DOMAIN"
    if state="$(vm_state)"; then
        printf 'VM state: %s\n' "$state"
    else
        printf 'VM state: unavailable\n'
    fi

    printf 'NVIDIA modules:'
    for module in nvidia nvidia_modeset nvidia_drm nvidia_uvm nvidia_peermem; do
        if [[ -d "/sys/module/$module" ]]; then
            printf ' %s=loaded' "$module"
        else
            printf ' %s=off' "$module"
        fi
    done
    printf '\n'

    for bdf in "$VIDEO_BDF" "$AUDIO_BDF"; do
        group="$(group_of "$bdf")"
        printf '%s  driver=%s  override=%s  iommu_group=%s\n' \
            "$bdf" "$(driver_of "$bdf")" "$(override_of "$bdf")" "$group"
    done
}

main() {
    case "${1:-}" in
        -h|--help|help) usage; exit 0 ;;
    esac

    require_root "$@"
    validate_config

    install -d -m 0755 /run/lock
    exec 9>"$LOCK_FILE"
    flock -n 9 || die "Another gpu-switch operation is already running"

    case "${1:-}" in
        vm) require_devices; switch_to_vm ;;
        host) require_devices; switch_to_host ;;
        status) require_devices; show_status ;;
        *) usage >&2; exit 2 ;;
    esac
}

main "$@"
