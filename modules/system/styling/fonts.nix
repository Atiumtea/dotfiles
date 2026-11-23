{
    config,
    lib,
    pkgs,
    ...
}: let
    cfg = config.hostSettings.styling.fonts;

    fontPresets = {
        jetbrains-mono-nerd = {
            name = "JetBrainsMono Nerd Font";
            package = pkgs.nerd-fonts.jetbrains-mono;
        };

        pxplus-ibm-xga-ai-12x20 = {
            name = "PxPlus IBM XGA-AI 12x20";
            package = pkgs.ultimate-oldschool-pc-font-pack;
        };

        swanston = {
            name = "Swanston";
            package = pkgs.callPackage ../../themes/retro/swanston.nix {};
        };

        terminus = {
            name = "Terminus (TTF)";
            package = pkgs.terminus_font_ttf;
        };
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
                monospacePreset = lib.mkOption {
                    type = lib.types.enum (builtins.attrNames fontPresets);
                    default = "jetbrains-mono-nerd";
                    description = "System-wide monospace font; Waybar always uses JetBrainsMono Nerd Font";
                };

                serif = fontBlock {
                    name = "Fira Sans";
                    package = pkgs.fira-sans;
                };

                sansSerif = fontBlock {
                    name = "Fira Sans";
                    package = pkgs.fira-sans;
                };

                monospace = fontBlock fontPresets.${cfg.monospacePreset};

                emoji = fontBlock {
                    name = "Twitter Color Emoji";
                    package = pkgs.twitter-color-emoji;
                };
            };
        };
    };

    config = lib.mkIf config.hostSettings.styling.enable {
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

            packages = lib.unique [
                cfg.serif.package
                cfg.sansSerif.package
                cfg.monospace.package
                cfg.emoji.package

                pkgs.corefonts
                # Keep Nerd Font available for Waybar, regardless of the selected system font.
                pkgs.nerd-fonts.jetbrains-mono
            ];

            fontDir.enable = true;
        };
    };
}
