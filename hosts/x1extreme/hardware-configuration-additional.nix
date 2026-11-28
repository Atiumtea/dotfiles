{
    config,
    lib,
    pkgs,
    ...
}: {
    imports = [
        ./hardware-configuration.nix
    ];

    boot.kernelParams =
        lib.optionals config.hostSettings.virtualization.libvirt.enable [
            # Intel VT-d for libvirt PCI device assignment.
            "intel_iommu=on"

            # Reserve the NVIDIA GPU and its HDMI audio function for VFIO.
            "vfio-pci.ids=10de:1f91,10de:10fa"
        ]
        ++ [
            # Samsung 970 EVO NVMe stability workaround
            "pcie_aspm=off"
        ];

    # Claim NVIDIA devices through VFIO before host GPU drivers initialize.
    boot.initrd.kernelModules = lib.optionals config.hostSettings.virtualization.libvirt.enable [
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
    ];
    # here goes all additional hardware configuration you may need
}
