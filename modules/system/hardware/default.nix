{
    config,
    lib,
    ...
}: {
    imports = [
        ./graphics

        ./bluetooth.nix
        ./laptop.nix
        ./uinput.nix
    ];

    config = lib.mkMerge [
        {
            hardware.enableAllFirmware = true;
        }

        (lib.mkIf config.services.throttled.enable {
            services.upower.enable = true;
        })
    ];
}
