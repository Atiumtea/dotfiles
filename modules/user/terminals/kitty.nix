{
    config,
    lib,
    osConfig,
    ...
}: let
    currentTheme = config.userSettings.styling.theme;
    opacityMap = {}; # in case override is needed
    retroTheme =
        osConfig.hostSettings.styling.enable
        && osConfig.hostSettings.styling.theme == "retro";

    opacity =
        if opacityMap ? currentTheme
        then opacityMap.${currentTheme}
        else "0.6";
in {
    options = {
        userSettings = {
            terminals.kitty.enable = lib.mkEnableOption "kitty";
        };
    };

    config = lib.mkIf config.userSettings.terminals.kitty.enable {
        programs.kitty = {
            enable = true;
            settings =
                {
                    modify_font = "cell_width 90%";
                    disable_ligatures = "cursor";
                    background_opacity = lib.mkForce opacity;
                    enable_audio_bell = false;
                    confirm_os_window_close = 0;
                }
                // lib.optionalAttrs retroTheme {
                    foreground = lib.mkForce "#${config.lib.stylix.colors.base04}";
                };
        };
    };
}
