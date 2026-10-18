{
    config,
    lib,
    pkgs,
    ...
}: {
    config = {
        hostSettings = {
            kernel.cachy = {
                enable = false;
                # variant = "gcc";
                # arch = "x86_64-v2";
            };

            users = [
                {
                    name = "atiumtea";
                    isAdmin = true;
                }
            ];

            security.sudo-rs.enable = true;
            hardware.graphics.nvidia.enable = true;
            hardware.graphics.amd.enable = false;
            hardware.laptop.enable = true;
            hardware.bluetooth.enable = true;
            audio.enable = true;
            desktop.hyprland.enable = true;
            sddm.enable = true;
            virtualization.docker.enable = true;
            virtualization.libvirt.enable = true;
            mullvad.enable = true;
            gaming.enable = true;

            styling = {
                enable = true;
                theme = "blood-moon";

                fonts = {
                    serif = {
                        name = "Fira Sans";
                        package = pkgs.fira-sans;
                    };
                };

                plymouth.enable = true;
                plymouth.theme = "arasaka";
                grub.theme = "cybergrub-2077";
            };
        };

        boot.loader.systemd-boot.enable = lib.mkForce false;

        # ThinkPad X1 Extreme Gen 2 — verify bus IDs with:
        #   lspci -D | grep -E 'VGA|3D controller|Display controller'
        hardware.nvidia.prime = {
            intelBusId = "PCI:0@0:2:0";
            nvidiaBusId = "PCI:1@0:0:0";
        };

        users.users.atiumtea.extraGroups = ["libvirtd"];

        networking.networkmanager.enable = true;
        networking.firewall.enable = lib.mkForce true;

        # Disable inbound Steam ports (not needed for normal gameplay)
        programs.steam.remotePlay.openFirewall = lib.mkForce false;
        programs.steam.dedicatedServer.openFirewall = lib.mkForce false;
        programs.steam.localNetworkGameTransfers.openFirewall = lib.mkForce false;

        programs.nh.flake = lib.mkForce "/home/atiumtea/dotfiles";
        time.timeZone = lib.mkForce "Europe/Minsk";

        system.stateVersion = "26.05";
    };
}
