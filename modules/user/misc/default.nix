{
    config,
    osConfig,
    lib,
    pkgs,
    ...
}: {
    options = {
        userSettings = {
            misc.enable = lib.mkEnableOption "miscellaneous programs";
        };
    };

    imports = [
        ./music.nix
        ./obsidian.nix
    ];

    config = lib.mkIf config.userSettings.misc.enable {
        home.packages = with pkgs; [
            discord
            pi
            python3
            nixd
            alejandra
            nix-output-monitor
            nvd
            nix-tree
        ];

        programs = {
            feh.enable = true;
            mpv.enable = true;

            btop = {
                enable = true;
                # needed for btop to show nVidia & AMD GPUs
                package = pkgs.btop.override {
                    cudaSupport = osConfig.hostSettings.hardware.graphics.nvidia.enable;
                    rocmSupport = osConfig.hostSettings.hardware.graphics.amd.enable;
                };
                settings = {
                    theme_background = true;
                    truecolor = true;
                    vim_keys = true;
                    update_ms = 100;
                };
            };
            lazydocker = lib.mkIf osConfig.hostSettings.virtualization.docker.enable {
                enable = true;
            };
        };
    };
}
