{
    config,
    lib,
    pkgs,
    ...
}: {
    imports = [
        ./hardware-configuration.nix
    ];

    boot.kernelParams = [
        # Samsung 970 EVO NVMe stability workaround
        "pcie_aspm=off"
    ];
    # here goes all additional hardware configuration you may need
}
