{
    config,
    lib,
    ...
}: let
    cfg = config.hostSettings.desktop;
in {
    options = {
        hostSettings = {
            desktop.enable = lib.mkOption {
                default = cfg.hyprland.enable || cfg.niri.enable || cfg.x11.enable;
                internal = true;
                visible = false;
                readOnly = true;
            };
        };
    };

    imports = [
        ./hyprland.nix
        ./niri.nix
        ./x11.nix
    ];

    config = lib.mkIf config.hostSettings.desktop.enable {
        services.gnome.gnome-keyring.enable = true;
    };
}
