{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        hostSettings = {
            virtualization = {
                libvirt.enable = lib.mkEnableOption "libvirt support";
                docker.enable = lib.mkEnableOption "Docker support";
                lookingGlass.enable = lib.mkEnableOption "Looking Glass support";
                gpuPassthrough.enable = lib.mkEnableOption "dynamic GPU passthrough";
            };
        };
    };

    config = lib.mkMerge [
        # Restore the virtualization services independently of Looking Glass.
        (lib.mkIf config.hostSettings.virtualization.libvirt.enable {
            virtualisation.libvirtd = {
                enable = true;
                qemu = {
                    package = pkgs.qemu_kvm;
                    vhostUserPackages = [pkgs.virtiofsd];
                };
            };

            virtualisation.spiceUSBRedirection.enable = true;
            programs.virt-manager.enable = true;
        })

        (lib.mkIf config.hostSettings.virtualization.docker.enable {
            virtualisation.docker.enable = true;
        })

        (lib.mkIf (
                config.hostSettings.virtualization.libvirt.enable
                && (
                    config.hostSettings.virtualization.lookingGlass.enable
                    || config.hostSettings.virtualization.gpuPassthrough.enable
                )
            ) {
                # Intel VT-d / IOMMU for Looking Glass and PCI passthrough.
                boot.kernelParams = ["intel_iommu=on"];
            })

        (lib.mkIf (
                config.hostSettings.virtualization.libvirt.enable
                && config.hostSettings.virtualization.gpuPassthrough.enable
            ) {
                # Load VFIO support without binding any PCI device at boot.
                boot.kernelModules = ["vfio-pci"];
            })

        (lib.mkIf (
                config.hostSettings.virtualization.libvirt.enable
                && config.hostSettings.virtualization.lookingGlass.enable
            ) {
                # Looking Glass shared-memory backing.
                boot.kernelParams = ["kvmfr.static_size_mb=32"];

                # Looking Glass KVMFR module, built for the active kernel.
                boot.extraModulePackages = [
                    config.boot.kernelPackages.kvmfr
                ];

                boot.initrd.kernelModules = ["kvmfr"];

                # Dedicated group for the KVMFR device.
                users.groups.kvm = {};

                services.udev.packages = lib.singleton (
                    pkgs.writeTextFile {
                        name = "looking-glass-kvmfr-udev";
                        destination = "/etc/udev/rules.d/70-kvmfr.rules";
                        text = ''
                            SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", TAG+="uaccess"
                        '';
                    }
                );

                # Permit QEMU to access the KVMFR device.
                virtualisation.libvirtd.qemu.verbatimConfig = ''
                    namespaces = []

                    cgroup_device_acl = [
                        "/dev/null",
                        "/dev/full",
                        "/dev/zero",
                        "/dev/random",
                        "/dev/urandom",
                        "/dev/ptmx",
                        "/dev/kvm",
                        "/dev/kqemu",
                        "/dev/rtc",
                        "/dev/hpet",
                        "/dev/vfio/vfio",
                        "/dev/kvmfr0"
                    ]
                '';
            })
    ];
}
