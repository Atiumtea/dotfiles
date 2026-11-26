{
    config,
    inputs,
    lib,
    osConfig,
    pkgs,
    ...
}: let
    cfg = config.userSettings.qbittorrent;
    palette = config.lib.stylix.colors;

    colorMappings = [
        {from = "#000000"; to = palette.base00;}
        {from = "#0a0a0a"; to = palette.base00;}
        {from = "#141414"; to = palette.base01;}
        {from = "#1e1e1e"; to = palette.base01;}
        {from = "#2d2d2d"; to = palette.base02;}
        {from = "#3a2a1c"; to = palette.base02;}
        {from = "#636363"; to = palette.base03;}
        {from = "#757575"; to = palette.base03;}
        {from = "#b3b3b3"; to = palette.base04;}
        {from = "#d9b98c"; to = palette.base06;}
        {from = "#ffffff"; to = palette.base05;}
        {from = "#fae2c8"; to = palette.base07;}
        {from = "#ff9e3b"; to = palette.base0A;}
        {from = "#ffb86c"; to = palette.base09;}
        {from = "#f08d49"; to = palette.base09;}
        {from = "#ff6b6b"; to = palette.base08;}
        {from = "#b9d665"; to = palette.base0B;}
        {from = "#aee6d6"; to = palette.base0C;}
        {from = "#9cd9e6"; to = palette.base0D;}
        {from = "#eba4be"; to = palette.base0E;}
    ];

    replacePalette = source:
        lib.replaceStrings
        (map (mapping: mapping.from) colorMappings)
        (map (mapping: "#${mapping.to}") colorMappings)
        source;

    stylesheet = pkgs.writeText "catthode-stylix.qss"
        (replacePalette (builtins.readFile "${inputs.catthode}/src/stylesheet.qss"));

    configJson = pkgs.writeText "catthode-stylix.json"
        (replacePalette (builtins.readFile "${inputs.catthode}/src/config.json"));

    resources = pkgs.writeText "catthode-stylix.qrc" ''
        <RCC>
            <qresource prefix="/uitheme">
                <file alias="stylesheet.qss">${stylesheet}</file>
                <file alias="config.json">${configJson}</file>
            </qresource>
        </RCC>
    '';

    theme = pkgs.runCommand "catthode-stylix.qbtheme" {
        nativeBuildInputs = [pkgs.qt6.qtbase];
    } ''
        mkdir -p "$out/share/qBittorrent/themes"
        mkdir -p "$out/share/licenses/catthode-qbittorrent"

        rcc --binary -no-compress ${resources} \
            -o "$out/share/qBittorrent/themes/stylix.qbtheme"

        cp ${inputs.catthode}/LICENSE \
            "$out/share/licenses/catthode-qbittorrent/LICENSE"
    '';
in {
    options.userSettings.qbittorrent.enable =
        lib.mkEnableOption "qBittorrent";

    config = lib.mkMerge [
        (lib.mkIf cfg.enable {
            home.packages = [pkgs.qbittorrent];
        })

        (lib.mkIf (
            cfg.enable
            && osConfig.hostSettings.styling.enable
        ) {
            xdg.configFile."qBittorrent/themes/stylix.qbtheme".source =
                "${theme}/share/qBittorrent/themes/stylix.qbtheme";
        })
    ];
}