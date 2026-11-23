{
    config,
    lib,
    pkgs,
    ...
}: let
    cfg = config.hostSettings.styling.fonts;

    retroTheme = config.hostSettings.styling.theme == "retro";

    retroFont = {
        name = "PxPlus IBM XGA-AI 12x20";
        package = pkgs.ultimate-oldschool-pc-font-pack;
    };

    fontBlock = default: {
        name = lib.mkOption {
            type = lib.types.str;
            default = default.name;
            description = "Font name";
        };

        package = lib.mkOption {
            type = lib.types.package;
            default = default.package;
            description = "Package providing font";
        };
    };
in {
    options = {
        hostSettings = {
            styling.fonts = {
                serif = fontBlock {
                    name = "Fira Sans";
                    package = pkgs.fira-sans;
                };

                sansSerif = fontBlock {
                    name = "Fira Sans";
                    package = pkgs.fira-sans;
                };

                monospace = fontBlock {
                    name = "JetBrainsMono Nerd Font";
                    package = pkgs.nerd-fonts.jetbrains-mono;
                };

                emoji = fontBlock {
                    name = "Twitter Color Emoji";
                    package = pkgs.twitter-color-emoji;
                };
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.hostSettings.styling.enable {
            fonts = {
                fontconfig = {
                    enable = true;

                    defaultFonts = {
                        serif = [cfg.serif.name];
                        sansSerif = [cfg.sansSerif.name];
                        monospace = [cfg.monospace.name];
                        emoji = [cfg.emoji.name];
                    };
                };

                packages = lib.unique (
                    [
                        cfg.serif.package
                        cfg.sansSerif.package
                        cfg.monospace.package
                        cfg.emoji.package

                        pkgs.corefonts
                    ]
                    ++ lib.optional retroTheme pkgs.nerd-fonts.jetbrains-mono
                );

                fontDir.enable = true;
            };
        })
        (lib.mkIf (config.hostSettings.styling.enable && retroTheme) {
            hostSettings.styling.fonts.serif.name = lib.mkForce retroFont.name;
            hostSettings.styling.fonts.serif.package = lib.mkForce retroFont.package;
            hostSettings.styling.fonts.sansSerif.name = lib.mkForce retroFont.name;
            hostSettings.styling.fonts.sansSerif.package = lib.mkForce retroFont.package;
            hostSettings.styling.fonts.monospace.name = lib.mkForce retroFont.name;
            hostSettings.styling.fonts.monospace.package = lib.mkForce retroFont.package;
        })
    ];
}
