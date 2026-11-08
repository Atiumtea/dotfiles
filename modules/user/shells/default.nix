{
    lib,
    pkgs,
    osConfig,
    username,
    ...
}: {
    imports = [
        ./zsh.nix
    ];

    config = {
        # maybe a better check?
        userSettings.shells.zsh.enable = lib.mkIf (osConfig.users.users.${username}.shell == pkgs.zsh) true;

        home.packages = with pkgs; [
            ripgrep
            fd
            jq
        ];

        programs = {
            fastfetch = {
                enable = true;
                settings = {
                    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
                    logo = {
                        source = "nixos_small";
                        padding.top = 1;
                        color = {
                            "1" = "red";
                            "2" = "red";
                        };
                    };
                    display.separator = "  ->  ";
                    modules = [
                        "break"
                        {
                            type = "title";
                            format = "{user-name}@{host-name}";
                        }
                        {
                            type = "os";
                            key = "os     ";
                            keyColor = "red";
                        }
                        {
                            type = "kernel";
                            key = "kernel ";
                            keyColor = "red";
                        }
                        {
                            type = "host";
                            format = "{5} {1}";
                            key = "host   ";
                            keyColor = "red";
                        }
                        {
                            type = "packages";
                            format = "{nix-system} (nixos), {nix-user} (hm)";
                            key = "pkgs   ";
                            keyColor = "red";
                        }
                        {
                            type = "uptime";
                            format = "{2}h {3}m";
                            key = "uptime ";
                            keyColor = "red";
                        }
                        {
                            type = "memory";
                            key = "memory ";
                            keyColor = "red";
                        }
                        {
                            type = "custom";
                            format = "the blood must flow";
                        }
                        "break"
                    ];
                };
            };
            bat.enable = true;
            direnv = {
                enable = true;
                nix-direnv.enable = true;
            };
            fzf = {
                enable = true;
                tmux.enableShellIntegration = true;
            };
            zoxide = {
                enable = true;
                options = ["--cmd cd"];
            };
            eza = {
                enable = true;
                # it adds too many aliases i don't use
                enableZshIntegration = lib.mkDefault false;
            };
            tmux = {
                enable = true;
                sensibleOnTop = true;
                terminal = "\${TERM}";

                escapeTime = 0;
                mouse = true;

                keyMode = "vi";
                shortcut = "Space";

                plugins = [
                    {
                        plugin = pkgs.tmuxPlugins.yank;
                    }
                    {
                        plugin = pkgs.tmuxPlugins.vim-tmux-navigator;
                    }
                ];

                extraConfig = ''
                    set -g base-index 1
                    set -g pane-base-index 1
                    set-window-option -g pane-base-index 1
                    set-option -g renumber-windows on

                    bind-key -r -T prefix C-Up resize-pane -U
                    bind-key -r -T prefix C-Down resize-pane -D
                    bind-key -r -T prefix C-Left resize-pane -L
                    bind-key -r -T prefix C-Right resize-pane -R

                    bind-key -T copy-move-vi v send-keys -X begin-selection
                    bind-key -T copy-move-vi C-v send-keys -X rectangle toggle
                    bind-key -T copy-move-vi y send-key -X copy-selection-and-cancel

                    bind \\ split-window -h -c "#{pane_current_path}"
                    bind - split-window -v -c "#{pane_current_path}"
                    unbind '"'
                    unbind %
                '';
            };
            starship = {
                enable = true;
                settings = {
                    add_newline = true;

                    format = "$directory$git_branch$git_status\n$nix_shell$character";
                    right_format = "$cmd_duration$time";

                    character = {
                        success_symbol = "[▶](bold red)";
                        error_symbol = "[▶](bold red)";
                        vimcmd_symbol = "[⧖](bold red)";
                    };

                    directory = {
                        truncation_length = 999;
                        truncate_to_repo = false;
                        style = "bold red";
                        read_only = "  ";
                    };

                    git_branch = {
                        format = "[$symbol$branch(:$remote_branch)]($style)";
                        symbol = " ";
                        style = "bold white";
                    };

                    git_status = {
                        format = "[$all_status]($style)";
                        style = "bold yellow";
                    };

                    nix_shell = {
                        format = "[\\(shell\\)]($style) ";
                    };

                    cmd_duration = {
                        min_time = 5000;
                        show_milliseconds = true;
                        format = "[$duration]($style)";
                    };

                    time = {
                        format = "[$time]($style)";
                        time_format = "%H:%M:%S";
                        disabled = false;
                    };
                };
            };
        };

        home.shellAliases = {
            ls = "eza --color=always";
            cat = "bat";
            ".." = "cd ..";
        };
    };
}
