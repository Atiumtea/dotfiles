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

    schedulerState = pkgs.writeShellScript "hyproled-scheduler-state" ''
        set -Eeuo pipefail

        status_json="$(${hyproledPackage}/bin/hyproled --status)"
        ${pkgs.jq}/bin/jq -r '
            .class as $classes
            | if ($classes | type) != "array" then
                error("Hyproled status does not contain a class array")
              elif ($classes | index("error")) != null then
                error("Hyproled state requires recovery")
              else
                (
                    ($classes | index("active") != null)
                    and (
                        any($classes[]; startswith("mask-"))
                        or (
                            ($classes | index("pixel-shift-enabled") != null)
                            and ($classes | index("pixel-shift-mode-fixed") == null)
                        )
                    )
                )
              end
        ' <<<"$status_json"
    '';

    effectStepRunner = pkgs.writeShellScript "hyproled-effect-step" ''
        set -Eeuo pipefail

        should_step="$(${schedulerState})"
        [[ "$should_step" == true ]] || exit 0

        exec ${hyproledPackage}/bin/hyproled -s
    '';

    schedulerSync = pkgs.writeShellScript "hyproled-scheduler-sync" ''
        set -Eeuo pipefail

        state_dir="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hyproled"
        ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
        ${pkgs.coreutils}/bin/chmod 700 "$state_dir"

        # Serialize scheduler decisions with hyproled state transactions.
        exec 9>"$state_dir/lock"
        ${pkgs.util-linux}/bin/flock 9

        if ! should_step="$(${schedulerState})"; then
            ${pkgs.systemd}/bin/systemctl --user stop hyproled-pixel-shift.timer || true
            exit 1
        fi

        case "$should_step" in
            true)
                # Restart the one-shot timer from the latest committed state change.
                exec ${pkgs.systemd}/bin/systemctl --user restart hyproled-pixel-shift.timer
                ;;
            false)
                exec ${pkgs.systemd}/bin/systemctl --user stop hyproled-pixel-shift.timer
                ;;
            *)
                printf 'hyproled: invalid scheduler state: %s\n' "$should_step" >&2
                ${pkgs.systemd}/bin/systemctl --user stop hyproled-pixel-shift.timer || true
                exit 1
                ;;
        esac
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
            enable = lib.mkEnableOption "automatic hyproled active-effect advancement";

            interval = lib.mkOption {
                type = lib.types.str;
                default = "15min";
                description = "Interval between automatic steps of active dynamic hyproled effects.";
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

        # The path unit reacts to runtime state updates; the timer exists only
        # while at least one dynamic effect needs periodic advancement.
        (lib.mkIf (osConfig.hostSettings.desktop.hyprland.enable && autoShift.enable) {
            systemd.user.services.hyproled-pixel-shift = {
                Unit = {
                    Description = "Advance active dynamic hyproled effects";
                };

                Service = {
                    Type = "oneshot";
                    ExecStart = "${effectStepRunner}";
                };
            };

            systemd.user.timers.hyproled-pixel-shift = {
                Unit = {
                    Description = "Periodically advance active dynamic hyproled effects";
                };

                Timer = {
                    # The path-triggered sync service rearms this one-shot timer
                    # after every committed hyproled state update.
                    OnActiveSec = autoShift.interval;
                    AccuracySec = "1min";
                    Unit = "hyproled-pixel-shift.service";
                };
            };

            systemd.user.services.hyproled-scheduler-sync = {
                Unit = {
                    Description = "Synchronize the hyproled timer with active effects";
                };

                Service = {
                    Type = "oneshot";
                    ExecStart = "${schedulerSync}";
                };
            };

            systemd.user.paths.hyproled-scheduler = {
                Unit = {
                    Description = "Watch hyproled runtime state for scheduler changes";
                };

                Path = {
                    PathChanged = "%t/hyproled";
                    MakeDirectory = true;
                    DirectoryMode = "0700";
                    Unit = "hyproled-scheduler-sync.service";
                };

                Install = {
                    WantedBy = ["default.target"];
                };
            };

            # Reconcile immediately when Home Manager is switched in a running
            # Hyprland session, even if the runtime state did not change.
            home.activation.hyproledSchedulerSync = lib.hm.dag.entryAfter ["reloadSystemd"] ''
                if [[ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" &&
                      -n "''${XDG_RUNTIME_DIR:-}" &&
                      -S "$XDG_RUNTIME_DIR/bus" ]]; then
                    $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user start hyproled-scheduler-sync.service
                fi
            '';
        })
    ];
}
