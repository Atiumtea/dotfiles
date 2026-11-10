{
    config,
    inputs,
    lib,
    osConfig,
    pkgs,
    ...
}: let
    cfg = config.userSettings.hyproled;
    autoShift = cfg.autoShift;

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
    options.userSettings.hyproled = {
        initialState = {
            maskEnabled = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether the OLED mask is enabled on the first launch or after declarative defaults change.";
            };

            pixelShiftEnabled = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether Pixel Shift is enabled on the first launch or after declarative defaults change.";
            };

            pixelShiftMode = lib.mkOption {
                type = lib.types.enum [
                    "linear-horizontal"
                    "linear-vertical"
                    "orbit-2x2"
                    "orbit-3x3"
                ];
                default = "orbit-2x2";
                description = "Initial Pixel Shift mode. Fixed remains available through the CLI.";
            };

            pixelShiftIndex = lib.mkOption {
                type = lib.types.ints.between 0 8;
                default = 0;
                description = "Initial Pixel Shift position index.";
            };

            maskPhase = lib.mkOption {
                type = lib.types.ints.between 0 3;
                default = 0;
                description = "Initial 2x2 mask phase.";
            };

            disabledPixels = lib.mkOption {
                type = lib.types.ints.between 1 3;
                default = 1;
                description = "Initial number of disabled pixels in each 2x2 block.";
            };

            monitor = lib.mkOption {
                type = lib.types.ints.unsigned;
                default = 0;
                description = "Hyprland monitor ID used by hyproled.";
            };

            area = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Optional mask area in x:y:w:h format.";
            };

            invert = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to invert the configured mask area.";
            };
        };

        brightness = {
            device = lib.mkOption {
                type = lib.types.str;
                default = "intel_backlight";
                description = "brightnessctl device used for optional OLED brightness compensation.";
            };

            compensationEnabled = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Initial preference for brightness compensation. Disabled by default.";
            };

            compensationPercentOfMaxByPixelCount = lib.mkOption {
                type = lib.types.attrsOf lib.types.int;
                default = {
                    "1" = 10;
                    "2" = 20;
                    "3" = 30;
                };
                description = "Brightness compensation percentages of maximum brightness for 1, 2, or 3 disabled pixels.";
            };
        };

        autoShift = {
            enable = lib.mkEnableOption "automatic hyproled Pixel Shift advancement";

            interval = lib.mkOption {
                type = lib.types.str;
                default = "15min";
                description = "Interval between automatic Pixel Shift position changes.";
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf osConfig.hostSettings.desktop.hyprland.enable {
            assertions = [
                {
                    assertion =
                        cfg.initialState.pixelShiftIndex
                        <= (
                            if cfg.initialState.pixelShiftMode == "orbit-3x3"
                            then 8
                            else if cfg.initialState.pixelShiftMode == "orbit-2x2"
                            then 3
                            else 1
                        );
                    message = "userSettings.hyproled.initialState.pixelShiftIndex is outside the selected Pixel Shift mode's range.";
                }
                {
                    assertion = let
                        percentages = cfg.brightness.compensationPercentOfMaxByPixelCount;
                    in
                        builtins.all (
                            key:
                                builtins.hasAttr key percentages
                                && percentages.${key} >= 0
                                && percentages.${key} <= 1000
                        ) ["1" "2" "3"];
                    message = "userSettings.hyproled.brightness.compensationPercentOfMaxByPixelCount must define keys 1, 2, and 3 with values from 0 to 1000.";
                }
                {
                    assertion =
                        cfg.initialState.area
                        == null
                        || builtins.match "^[0-9]+:[0-9]+:[0-9]+:[0-9]+$" cfg.initialState.area != null;
                    message = "userSettings.hyproled.initialState.area must be null or use x:y:w:h format.";
                }
                {
                    assertion = cfg.brightness.device != "";
                    message = "userSettings.hyproled.brightness.device must not be empty.";
                }
            ];

            home.packages = [hyproledPackage];

            xdg.configFile."hyproled/config.json".text = builtins.toJSON {
                version = 1;
                defaults = {
                    maskEnabled = cfg.initialState.maskEnabled;
                    pixelShift = cfg.initialState.pixelShiftEnabled;
                    pixelShiftMode = cfg.initialState.pixelShiftMode;
                    pixelShiftIndex = cfg.initialState.pixelShiftIndex;
                    phase = cfg.initialState.maskPhase;
                    disabledPixels = cfg.initialState.disabledPixels;
                    monitor = cfg.initialState.monitor;
                    area = cfg.initialState.area;
                    invert = cfg.initialState.invert;
                };
                brightness = {
                    enabled = cfg.brightness.compensationEnabled;
                    device = cfg.brightness.device;
                    compensationPercentOfMaxByPixelCount = cfg.brightness.compensationPercentOfMaxByPixelCount;
                };
            };
        })

        # The timer implementation is intentionally unchanged in this revision.
        (lib.mkIf (osConfig.hostSettings.desktop.hyprland.enable && autoShift.enable) {
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
                    OnStartupSec = autoShift.interval;
                    OnUnitActiveSec = autoShift.interval;
                    AccuracySec = "1min";
                    Unit = "hyproled-pixel-shift.service";
                };

                Install = {
                    WantedBy = ["timers.target"];
                };
            };
        })
    ];
}
