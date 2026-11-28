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
        ]
        ++ [
            # Samsung 970 EVO NVMe stability workaround
            "pcie_aspm=off"
        ];

    # Load VFIO support for libvirt-managed PCI device assignment.
    # PCI devices remain bound to their host drivers until a VM starts.
    boot.kernelModules = lib.optionals config.hostSettings.virtualization.libvirt.enable [
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
    ];
    # here goes all additional hardware configuration you may need
}
