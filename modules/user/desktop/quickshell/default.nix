{
    config,
    lib,
    osConfig,
    ...
}: {
    options.userSettings.quickshell.enable =
        lib.mkEnableOption "Quickshell";

    config =
        lib.mkIf (
            config.userSettings.quickshell.enable
            && osConfig.hostSettings.desktop.enable
        ) {
            programs.quickshell.enable = true;
        };
}
