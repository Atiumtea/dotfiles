{
    config,
    osConfig,
    lib,
    ...
}: let
    retroTheme =
        osConfig.hostSettings.styling.enable
        && osConfig.hostSettings.styling.theme == "retro";
in {
    config = lib.mkIf osConfig.hostSettings.desktop.hyprland.enable ({
            programs.hyprlock = {
                enable = true;
                settings =
                    {
                        general = {
                            fail_timeout = 1000;
                        };

                        animations = {
                            enabled = true;

                            bezier = [
                                "easeOutQuint,0.23,1,0.32,1"
                                "easeInOutCubic,0.65,0.05,0.36,1"
                            ];

                            animation = [
                                "global,1,10,default"
                                "fadeIn,1,8,easeInOutCubic"
                                "fadeOut,1,8,easeOutQuint"
                                "fade,1,3.03,quick"
                            ];
                        };

                        background =
                            {
                                monitor = "";
                                blur_passes = 3;
                            }
                            // lib.optionalAttrs retroTheme {
                                color = "$color";
                            };

                        label = [
                            {
                                text = "cmd[update:1000] echo -e \"$(LC_TIME=en_US.UTF-8 date +\"%A, %B %d\")\"";
                                font_size = 25;
                                font_family = "SF Pro Display Semibold";
                                position = "0, 30%";
                                halign = "center";
                                valign = "center";
                            }

                            {
                                text = "cmd[update:1000] echo \"<span>$(date +\"%H:%M\")</span>\"";
                                font_size = 120;
                                font_family = "SF Pro Display Bold";
                                position = "0, 20%";
                                halign = "center";
                                valign = "center";
                            }
                        ];

                        input-field =
                            {
                                size = "380, 65";
                                outline_thickness = 3;

                                dots_size = 0.28;
                                dots_spacing = 0.25;
                                dots_center = true;

                                fade_on_empty = false;
                                placeholder_text = "<span foreground=\"##ffaa44\">Fear is the mind-killer :3</span>";
                                fail_text = "<span foreground=\"##ff4444\">The Sandworm got your password! ($ATTEMPTS)</span>";

                                hide_input = false;
                                position = "0,-20";
                                halign = "center";
                                valign = "center";
                            }
                            // lib.optionalAttrs retroTheme {
                                outer_color = "$outer_color";
                                inner_color = "$inner_color";
                                font_color = "$font_color";
                                check_color = "$check_color";
                            };
                    }
                    // lib.optionalAttrs retroTheme {
                        source = "${config.xdg.configHome}/hypr/hyprlock-retro.conf";
                    };
            };
        }
        // lib.optionalAttrs retroTheme {
            stylix.targets.hyprlock.enable = false;

            xdg.configFile."hypr/hyprlock-retro.conf".source =
                ../../../themes/retro/hyprlock.conf;
        });
}
