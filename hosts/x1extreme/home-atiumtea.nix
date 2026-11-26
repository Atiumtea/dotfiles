{
    config,
    osConfig,
    lib,
    pkgs,
    ...
}: {
    config = {
        userSettings = {
            xdg.enable = true;
            nixvim.enable = true;
            shells.zsh.enable = true;
            security.enable = true;
            git.enable = true;
            misc.enable = true;
            qbittorrent.enable = true;
            quickshell.enable = true;

            hyproled.autoShift = {
                enable = true;
                interval = "3min";
            };

            waybar.toggle.enable = true;
            wattage.enable = true;

            vscode.enable = true;
            obsidian.enable = true;

            browsers = {
                defaultBrowser = "zen-browser";
                firefox.enable = true;
            };

            terminals = {
                defaultTerminal = "kitty";
                kitty.enable = true;
            };

            styling.cursor = {
                name = "Quintom_Snow";
                package = pkgs.quintom-cursor-theme;
                size = 24;
            };
        };

        services.blueman-applet.enable = true;

        # ShowConnected depends on StatusIcon and would load it again.
        dconf.settings."org/blueman/general".plugin-list = ["!StatusIcon" "!ShowConnected"];

        home.sessionVariables = {
            LIBVIRT_DEFAULT_URI = "qemu:///system";
        };

        wayland.windowManager.hyprland.settings.config.input.kb_layout =
            lib.mkForce "us,ru";

        wayland.windowManager.hyprland.settings.config.input.kb_options =
            lib.mkForce "grp:win_space_toggle";

        programs = {
            git = {
                enable = true;
                signing = {
                    key = "/home/atiumtea/.ssh/id_ed25519.pub";
                    signByDefault = true;
                    format = "ssh";
                };
                settings = {
                    user.name = "Atiumtea";
                    user.email = "brodaznik10k@gmail.com";
                };
            };

            gh = {
                enable = true;
                settings = {
                    git_protocol = "ssh";
                };
            };
        };

        # Create a writable directories for game files.
        home.activation.ensureGameDirectories = lib.hm.dag.entryAfter ["writeBoundary"] ''
            $DRY_RUN_CMD mkdir -p "$HOME/Games/Isaac" "$HOME/Games/WorldBox"
        '';

        home.stateVersion = "25.05";
    };
}
