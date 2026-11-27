{
    config,
    lib,
    pkgs,
    ...
}: let
    nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.production;

    # Apply the UVM reference-release fix to the open kernel module only.
    nvidiaPackageWithUnbindFix = nvidiaPackage.overrideAttrs (old: {
        passthru =
            old.passthru
            // {
                open = old.passthru.open.overrideAttrs (openOld: {
                    patches =
                        (openOld.patches or [])
                        ++ [
                            ./patches/nvidia-open-gpu-unbind.patch
                        ];
                });
            };
    });
in {
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
                package = nvidiaPackageWithUnbindFix;
            };

            nvidia-container-toolkit = lib.mkIf config.hostSettings.virtualization.docker.enable {
                enable = true;
            };
        };

        services.xserver.videoDrivers = ["modesetting" "nvidia"];
    };
}
