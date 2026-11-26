{
    config,
    lib,
    osConfig,
    ...
}: let
    font = osConfig.hostSettings.styling.fonts.monospace;
in {
    config = lib.mkIf osConfig.hostSettings.desktop.enable {
        programs.rofi = {
            enable = true;
            settings.font = "${font.name} 12";
            theme = let
                mkLiteral = config.lib.formats.rasi.mkLiteral;
                mkRgb = color: let
                    c = config.lib.stylix.colors;
                    r = c."${color}-rgb-r";
                    g = c."${color}-rgb-g";
                    b = c."${color}-rgb-b";
                in
                    mkLiteral "rgba(${r}, ${g}, ${b}, 100%)";
            in {
                "*" = {
                    background = mkRgb "base00";
                    lightbg = mkRgb "base01";
                    red = mkRgb "base08";
                    blue = mkRgb "base0D";
                    lightfg = mkRgb "base06";
                    foreground = mkRgb "base05";

                    background-color = mkRgb "base00";
                    separatorcolor = mkRgb "base04";
                    border-color = mkRgb "base04";
                    selected-normal-foreground = mkLiteral "@lightbg";
                    selected-normal-background = mkLiteral "@lightfg";
                    selected-active-foreground = mkLiteral "@background";
                    selected-active-background = mkLiteral "@blue";
                    selected-urgent-foreground = mkLiteral "@background";
                    selected-urgent-background = mkLiteral "@red";
                    normal-foreground = mkLiteral "@foreground";
                    normal-background = mkLiteral "@background";
                    active-foreground = mkLiteral "@blue";
                    active-background = mkLiteral "@background";
                    urgent-foreground = mkLiteral "@red";
                    urgent-background = mkLiteral "@background";
                    alternate-normal-foreground = mkLiteral "@foreground";
                    alternate-normal-background = mkLiteral "@lightbg";
                    alternate-active-foreground = mkLiteral "@blue";
                    alternate-active-background = mkLiteral "@lightbg";
                    alternate-urgent-foreground = mkLiteral "@red";
                    alternate-urgent-background = mkLiteral "@lightbg";

                    base-text = mkRgb "base05";
                    selected-normal-text = mkRgb "base01";
                    selected-active-text = mkRgb "base00";
                    selected-urgent-text = mkRgb "base00";
                    normal-text = mkRgb "base05";
                    active-text = mkRgb "base0D";
                    urgent-text = mkRgb "base08";
                    alternate-normal-text = mkRgb "base05";
                    alternate-active-text = mkRgb "base0D";
                    alternate-urgent-text = mkRgb "base08";
                };
            };
        };

        # Hide settings and terminal-only applications from GUI application launcher.
        xdg.desktopEntries = {
            "qt5ct" = {
                name = "Qt5 Settings";
                noDisplay = true;
            };

            "qt6ct" = {
                name = "Qt6 Settings";
                noDisplay = true;
            };

            "nvidia-settings" = {
                name = "NVIDIA X Server Settings";
                noDisplay = true;
            };

            "blueman-adapters" = {
                name = "Bluetooth Adapters";
                noDisplay = true;
            };

            "xdg-desktop-portal-gtk" = {
                name = "Portal";
                noDisplay = true;
            };

            "org.freedesktop.Xwayland" = {
                name = "Xwayland";
                noDisplay = true;
            };

            "org.quickshell" = {
                name = "Quickshell";
                noDisplay = true;
            };

            "rofi" = {
                name = "Rofi";
                noDisplay = true;
            };

            "rofi-theme-selector" = {
                name = "Rofi Theme Selector";
                noDisplay = true;
            };

            "code-url-handler" = {
                name = "Visual Studio Code - URL Handler";
                noDisplay = true;
            };

            "kitty-open" = {
                name = "kitty URL Launcher";
                noDisplay = true;
            };

            "umpv" = {
                name = "umpv Media Player";
                noDisplay = true;
            };

            "btop" = {
                name = "btop++";
                noDisplay = true;
            };

            "nvim" = {
                name = "Neovim wrapper";
                noDisplay = true;
            };

            "rmpc" = {
                name = "rmpc";
                noDisplay = true;
            };

            "yazi" = {
                name = "Yazi File Manager";
                noDisplay = true;
            };
        };

        xdg.configFile = {
            "rofi/launcher.rasi".source = ./launcher.rasi;
            "rofi/hyproled.rasi".source = ./hyproled.rasi;
            "rofi/nixos-control.rasi".source = ./nixos-control.rasi;
            "rofi/powermenu.rasi".source = ./powermenu.rasi;
            "rofi/powermenu.sh" = {
                source = ./powermenu.sh;
                executable = true;
            };
        };

        # custom implementation is needed due to stylix putting config for elements
        # and some opacity stuff which breaks everything
        stylix.targets.rofi.enable = false;
    };
}
