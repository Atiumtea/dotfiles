{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        hostSettings = {
            hardware.graphics.nvidia.enable = lib.mkEnableOption "nVidia GPU support";
        };
    };

    config = lib.mkIf config.hostSettings.hardware.graphics.nvidia.enable {
        hardware = {
            graphics.extraPackages = with pkgs; [
                nvidia-vaapi-driver
            ];

            nvidia = {
                open = true;
                modesetting.enable = true;
                powerManagement.enable = true;
                # Patch NVIDIA's UVM reference leak during dynamic PCI detach.
                package = config.boot.kernelPackages.nvidiaPackages.production.override {
                    patchesOpen = [
                        ./patches/nvidia-open-gpu-unbind.patch
                    ];
                };
            };

            nvidia-container-toolkit = lib.mkIf config.hostSettings.virtualization.docker.enable {
                enable = true;
            };
        };

        services.xserver.videoDrivers = ["modesetting" "nvidia"];
    };
}
