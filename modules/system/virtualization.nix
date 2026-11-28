{
    config,
    lib,
    pkgs,
    ...
}: let
    cfg = config.hostSettings.virtualization;

    gpuSwitch = pkgs.writeShellScriptBin "gpu-switch" ''
        export PATH="${lib.makeBinPath (with pkgs; [
            coreutils
            kmod
            libvirt
            psmisc
            systemd
            util-linux
        ])}:$PATH"
        export GPU_SWITCH_VIDEO_BDF=${lib.escapeShellArg cfg.gpuPassthrough.videoBdf}
        export GPU_SWITCH_AUDIO_BDF=${lib.escapeShellArg cfg.gpuPassthrough.audioBdf}
        export GPU_SWITCH_DOMAIN=${lib.escapeShellArg cfg.gpuPassthrough.domain}
        exec ${pkgs.bash}/bin/bash ${../../scripts/gpu-switch.sh} "$@"
    '';
in {
    options = {
        hostSettings = {
            virtualization = {
                libvirt.enable = lib.mkEnableOption "libvirt support";
                docker.enable = lib.mkEnableOption "Docker support";
                lookingGlass.enable = lib.mkEnableOption "Looking Glass support";
                gpuPassthrough = {
                    enable = lib.mkEnableOption "manual GPU passthrough switching";
                    videoBdf = lib.mkOption {
                        type = lib.types.str;
                        default = "0000:01:00.0";
                        description = "PCI address of the NVIDIA GPU function passed to the VM.";
                    };
                    audioBdf = lib.mkOption {
                        type = lib.types.str;
                        default = "0000:01:00.1";
                        description = "PCI address of the NVIDIA HDMI-audio function passed to the VM.";
                    };
                    domain = lib.mkOption {
                        type = lib.types.str;
                        default = "win10";
                        description = "Libvirt domain protected by gpu-switch.";
                    };
                };
            };
        };
    };

    config = lib.mkMerge [
        {
            assertions = lib.optionals cfg.gpuPassthrough.enable [
                {
                    assertion = cfg.libvirt.enable;
                    message = "GPU passthrough switching requires hostSettings.virtualization.libvirt.enable.";
                }
                {
                    assertion = config.hostSettings.hardware.graphics.nvidia.enable;
                    message = "GPU passthrough switching requires hostSettings.hardware.graphics.nvidia.enable.";
                }
            ];
        }

        # Restore the virtualization services independently of Looking Glass.
        (lib.mkIf cfg.libvirt.enable {
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

        (lib.mkIf cfg.docker.enable {
            virtualisation.docker.enable = true;
        })

        (lib.mkIf (
                cfg.libvirt.enable
                && (
                    cfg.lookingGlass.enable
                    || cfg.gpuPassthrough.enable
                )
            ) {
                # Intel VT-d / IOMMU for Looking Glass and PCI passthrough.
                boot.kernelParams = ["intel_iommu=on"];
            })

        (lib.mkIf (cfg.libvirt.enable && cfg.gpuPassthrough.enable) {
            # Load VFIO support, but leave PCI device binding to gpu-switch.
            boot.kernelModules = {
                "vfio-pci" = true;
                nvidia = lib.mkForce false;
                nvidia_modeset = lib.mkForce false;
                nvidia_drm = lib.mkForce false;
                nvidia_uvm = lib.mkForce false;
            };

            # Keep the NVIDIA driver installed for explicit `gpu-switch host` use,
            # but prevent PCI hardware probing from loading it during boot.
            boot.blacklistedKernelModules = [
                "nvidia"
                "nvidia_modeset"
                "nvidia_drm"
                "nvidia_uvm"
            ];

            environment.systemPackages = [gpuSwitch];
        })

        (lib.mkIf (cfg.libvirt.enable && cfg.lookingGlass.enable) {
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
