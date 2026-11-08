{
    config,
    inputs,
    lib,
    osConfig,
    pkgs,
    ...
}: let
    cfg = config.userSettings.hyproled.autoShift;

    hyproledPackage = import ../common/hyproled-package.nix {
        inherit inputs lib pkgs;
    };

    pixelShiftRunner = pkgs.writeShellScript "hyproled-pixel-shift-step" ''
        set -Eeuo pipefail

        state_file="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hyproled/state.json"

        # No active session is a normal condition.
        [[ -e "$state_file" ]] || exit 0

        if ! ${pkgs.jq}/bin/jq -e '
            type == "object" and
            (.version == 1 or .version == 2 or .version == 3 or .version == 4 or .version == 5) and
            (.status == "active" or .status == "applying" or .status == "restoring")
        ' "$state_file" >/dev/null; then
            printf 'hyproled: invalid state file; skipping automatic Pixel Shift\n' >&2
            exit 1
        fi

        status=$(${pkgs.jq}/bin/jq -r '.status' "$state_file")

        if [[ "$status" != "active" ]]; then
            printf 'hyproled: state requires recovery (%s); skipping Pixel Shift\n' "$status" >&2
            exit 1
        fi

        pixel_shift=$(${pkgs.jq}/bin/jq -r '.pixelShift // false' "$state_file")
        [[ "$pixel_shift" == true ]] || exit 0

        mode=$(${pkgs.jq}/bin/jq -r '
            if .version >= 5 then .pixelShiftMode else "fixed" end
        ' "$state_file")

        case "$mode" in
            fixed)
                exit 0
                ;;
            linear-horizontal|linear-vertical|orbit-2x2|orbit-3x3)
                ;;
            *)
                printf 'hyproled: invalid Pixel Shift mode: %s\n' "$mode" >&2
                exit 1
                ;;
        esac

        exec ${hyproledPackage}/bin/hyproled --shift-step
    '';
in {
    options.userSettings.hyproled.autoShift = {
        enable = lib.mkEnableOption "automatic hyproled Pixel Shift advancement";

        interval = lib.mkOption {
            type = lib.types.str;
            default = "15min";
            description = "Interval between automatic Pixel Shift position changes.";
        };
    };

    config = lib.mkIf (osConfig.hostSettings.desktop.hyprland.enable && cfg.enable) {
        home.packages = [hyproledPackage];

        systemd.user.services.hyproled-pixel-shift = {
            Unit = {
                Description = "Advance hyproled Pixel Shift position";
            };

            Service = {
                Type = "oneshot";
                ExecStart = "${pixelShiftRunner}";
            };
        };

        systemd.user.timers.hyproled-pixel-shift = {
            Unit = {
                Description = "Periodically advance hyproled Pixel Shift";
            };

            Timer = {
                OnStartupSec = cfg.interval;
                OnUnitActiveSec = cfg.interval;
                AccuracySec = "1min";
                Unit = "hyproled-pixel-shift.service";
            };

            Install = {
                WantedBy = ["timers.target"];
            };
        };
    };
}
