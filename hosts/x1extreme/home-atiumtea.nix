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

        # TODO: move to sops-nix when Go 1.26 lands in nixpkgs.
        # For now, set OPENROUTER_API_KEY in ~/.config/openrouter-key
        # and uncomment the line below:
        # home.sessionVariables.OPENROUTER_API_KEY = builtins.readFile
        #   "${config.home.homeDirectory}/.config/openrouter-key";

        services.blueman-applet.enable = true;

        wayland.windowManager.hyprland.settings.input.kb_layout =
            lib.mkForce "us,ru";

        wayland.windowManager.hyprland.settings.input.kb_options =
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

        home.stateVersion = "25.05";
    };
}
