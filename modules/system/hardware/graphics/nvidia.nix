{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        hostSettings = {
            hardware.graphics.nvidia.enable = lib.mkEnableOption "nVidia GPU support";
            hardware.graphics.nvidia.open = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Use the open NVIDIA kernel module.";
            };
        };
    };

    config = lib.mkIf config.hostSettings.hardware.graphics.nvidia.enable {
        hardware = {
            graphics.extraPackages = with pkgs; [
                nvidia-vaapi-driver
            ];

            nvidia = {
                open = config.hostSettings.hardware.graphics.nvidia.open;
                modesetting.enable = true;
                powerManagement.enable = true;
                package = config.boot.kernelPackages.nvidiaPackages.production;
            };

            nvidia-container-toolkit = lib.mkIf config.hostSettings.virtualization.docker.enable {
                enable = true;
            };
        };

        services.xserver.videoDrivers = ["modesetting" "nvidia"];
    };
}
