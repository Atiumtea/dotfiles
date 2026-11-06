{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        hostSettings = {
            hardware.uinput.enable = lib.mkEnableOption "uinput and game controller udev rules";
        };
    };

    config = lib.mkIf config.hostSettings.hardware.uinput.enable {
        hardware.uinput.enable = true;
        services.udev.packages = with pkgs; [game-devices-udev-rules];
    };
}
