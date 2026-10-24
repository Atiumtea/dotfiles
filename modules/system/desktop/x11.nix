{
    config,
    lib,
    ...
}: {
    options = {
        hostSettings = {
            desktop.x11.enable = lib.mkEnableOption "X11 session (for legacy/Wine apps)";
        };
    };

    config = lib.mkIf config.hostSettings.desktop.x11.enable {
        services.xserver = {
            enable = true;

            # Lightweight WM for running Wine/Cisco Packet Tracer
            windowManager.openbox.enable = true;

            # Keyboard layout matching Hyprland config
            xkb = {
                layout = "us,ru";
                options = "grp:win_space_toggle";
            };
        };
    };
}