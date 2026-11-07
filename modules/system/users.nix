{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        hostSettings = {
            users = lib.mkOption {
                description = "List of users to create on the host";

                type = lib.types.listOf (lib.types.submodule {
                    options = {
                        name = lib.mkOption {
                            type = lib.types.str;
                            description = "Username";
                        };

                        isAdmin = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Whether the user has administrative privileges";
                        };

                        shell = lib.mkOption {
                            type = lib.types.package;
                            default = pkgs.zsh;
                            description = "User login shell";
                        };

                        extraGroups = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [];
                            description = "Additional system groups assigned only to this user";
                            example = ["networkmanager" "input" "uinput"];
                        };
                    };
                });
            };
        };
    };

    config = {
        users.users = lib.listToAttrs (map (user: {
            name = user.name;

            value = {
                isNormalUser = true;

                extraGroups = lib.unique (
                    user.extraGroups
                    ++ lib.optional user.isAdmin "wheel"
                );

                createHome = true;

                shell = user.shell;
            };
        })
        config.hostSettings.users);

        home-manager.users = lib.listToAttrs (map (user: {
            name = user.name;
            value = {
                home = {
                    username = user.name;
                    homeDirectory = "/home/${user.name}";
                };
            };
        })
        config.hostSettings.users);

        # Enable zsh if necessary.
        programs.zsh = let
            zshUsed = builtins.any (
                user: user.shell == pkgs.zsh
            )
            config.hostSettings.users;
        in
            lib.mkIf zshUsed {
                enable = true;
            };
    };
}
