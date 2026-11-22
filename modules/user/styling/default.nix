{
    config,
    osConfig,
    lib,
    ...
}: {
    imports = [
        ./cursors.nix
        ./fonts.nix
        ./stylix.nix
        ./themes/retro.nix
    ];

    config = lib.mkIf osConfig.hostSettings.styling.enable {
        # GTK4 theme is handled by home-manager's Stylix integration now
    };
}
