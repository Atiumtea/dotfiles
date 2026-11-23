{
    config,
    osConfig,
    pkgs,
    lib,
    ...
}: let
    retroNixvim = import ../../../themes/retro/nixvim.nix;

    retroTheme =
        osConfig.hostSettings.styling.enable
        && osConfig.hostSettings.styling.theme == "retro";
in {
    config = lib.mkIf retroTheme {
        programs.btop = lib.mkIf config.userSettings.misc.enable {
            settings = {
                color_theme = "retro";
                theme_background = lib.mkForce false;
            };
            themes.retro = ../../../themes/retro/btop.theme;
        };

        services.mako = lib.mkIf osConfig.hostSettings.desktop.enable {
            settings = lib.mkForce (
                (import ../../../themes/retro/mako.nix)
                // {
                    font = osConfig.hostSettings.styling.fonts.monospace.name;
                }
            );
        };

        programs.nixvim = lib.mkIf config.userSettings.nixvim.enable {
            colorschemes.nightfox = retroNixvim.nightfox;
            plugins.lualine.settings.options.theme = retroNixvim.lualine;
        };

        programs.hyprlock = lib.mkIf osConfig.hostSettings.desktop.hyprland.enable {
            settings."input-field" = {
                placeholder_text = lib.mkForce ''
                    <span foreground="##FFCC00">Fear is the mind-killer :3</span>
                '';
                fail_text = lib.mkForce ''
                    <span foreground="##FF8800">The Sandworm got your password! ($ATTEMPTS)</span>
                '';
            };
        };

        userSettings.styling.cursor = {
            name = lib.mkForce "Bibata-Original-Amber";
            package = lib.mkForce pkgs.bibata-cursors;
        };

        wayland.windowManager.hyprland.settings = lib.mkIf osConfig.hostSettings.desktop.hyprland.enable {
            config = {
                general."col.active_border" = lib.mkForce "rgb(${config.lib.stylix.colors.base0A})";
                group = {
                    "col.border_active" = lib.mkForce "rgb(${config.lib.stylix.colors.base0A})";
                    "col.border_locked_active" = lib.mkForce "rgb(${config.lib.stylix.colors.base0A})";
                    groupbar."col.active" = lib.mkForce "rgb(${config.lib.stylix.colors.base0A})";
                };
            };
        };

        # Avoid overlapping directory/file ownership in Stylix's Kvantum target.
        stylix.targets.qt.enable = false;
        stylix.targets.btop.enable = lib.mkIf config.userSettings.misc.enable false;
        stylix.targets.mako.enable = lib.mkIf osConfig.hostSettings.desktop.enable false;
        stylix.targets.nixvim.enable = lib.mkIf config.userSettings.nixvim.enable false;
    };
}
