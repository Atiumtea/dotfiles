{...}: {
    imports = [
        ./graphics

        ./bluetooth.nix
        ./laptop.nix
        ./uinput.nix
    ];

    config = {
        hardware.enableAllFirmware = true;
    };
}
