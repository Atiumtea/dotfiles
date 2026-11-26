{
    config,
    osConfig,
    lib,
    pkgs,
    ...
}: let
    palette = config.lib.stylix.colors;

    colorNames = [
        "base00"
        "base01"
        "base02"
        "base03"
        "base04"
        "base05"
        "base06"
        "base07"
        "base08"
        "base09"
        "base0A"
        "base0B"
        "base0C"
        "base0D"
        "base0E"
        "base0F"
    ];

    replacePalette = source:
        lib.replaceStrings
        (map (name: "@${name}@") colorNames)
        (map (name: "#${palette.${name}}") colorNames)
        source;

    stylesheet =
        pkgs.writeText "qbittorrent-stylix.qss"
        (replacePalette (builtins.readFile ./qbittorrent-theme/stylesheet.qss));

    themeConfig =
        pkgs.writeText "qbittorrent-stylix.json"
        (replacePalette (builtins.readFile ./qbittorrent-theme/config.json));

    resources = pkgs.writeText "qbittorrent-stylix.qrc" ''
        <RCC>
            <qresource prefix="/uitheme">
                <file alias="stylesheet.qss">${stylesheet}</file>
                <file alias="config.json">${themeConfig}</file>
            </qresource>
        </RCC>
    '';

    theme =
        pkgs.runCommand "qbittorrent-stylix.qbtheme" {
            nativeBuildInputs = [pkgs.qt6.qtbase];
        } ''
            rcc --binary -no-compress ${resources} -o "$out"
        '';
in {
    config =
        lib.mkIf (
            config.userSettings.misc.enable
            && osConfig.hostSettings.styling.enable
        ) {
            xdg.configFile."qBittorrent/themes/stylix.qbtheme".source = theme;
        };
}
