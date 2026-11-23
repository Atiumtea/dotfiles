{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        hostSettings.hardware.laptop.enable = lib.mkEnableOption "laptop support";
    };

    config = lib.mkIf config.hostSettings.hardware.laptop.enable {
        hardware.nvidia = lib.mkIf config.hostSettings.hardware.graphics.nvidia.enable {
            prime.offload = {
                enable = true;
                enableOffloadCmd = true;
            };

            powerManagement.finegrained = true;
        };

        services = {
            upower.enable = true;
            power-profiles-daemon.enable = true;
        };

        environment.systemPackages = lib.optional config.hostSettings.hardware.graphics.enable pkgs.brightnessctl;
    };
}
