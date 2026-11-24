{
    config,
    inputs,
    lib,
    osConfig,
    pkgs,
    ...
}: let
    cfg = config.userSettings.wattage;
in {
    options.userSettings.wattage.enable =
        lib.mkEnableOption "Wattage battery monitor";

    config = lib.mkIf (osConfig.hostSettings.desktop.enable && cfg.enable) {
        home.packages = [
            inputs.wattage.packages.${pkgs.system}.default
        ];
    };
}
