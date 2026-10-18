{
    config,
    lib,
    pkgs,
    inputs,
    osConfig,
    ...
}: {
    options = {
        userSettings = {
            browsers.zen-browser = {
                enable = lib.mkEnableOption "Zen Browser";
                path = lib.mkOption {
                    type = lib.types.str;
                    default = "zen-beta";
                    internal = true;
                    visible = false;
                };
            };
        };
    };

    imports = [
        inputs.zen-browser.homeModules.beta
    ];

    config = lib.mkIf config.userSettings.browsers.zen-browser.enable {
        programs.zen-browser = {
            enable = true;
            setAsDefaultBrowser = true;

            profiles.default = {
                id = 0;
                isDefault = true;
            };
        };

        stylix.targets.zen-browser.profileNames = ["default"];

        home.sessionVariables.BROWSER = lib.mkForce "zen-beta";

        wayland.windowManager.hyprland.settings."$browser" =
            lib.mkIf osConfig.hostSettings.desktop.hyprland.enable
            (lib.mkForce "zen-beta");
    };
}
