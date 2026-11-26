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
        {
            from = "#000000";
            to = palette.base00;
        }
        {
            from = "#0a0a0a";
            to = palette.base00;
        }
        {
            from = "#141414";
            to = palette.base01;
        }
        {
            from = "#1e1e1e";
            to = palette.base01;
        }
        {
            from = "#2d2d2d";
            to = palette.base02;
        }
        {
            from = "#3a2a1c";
            to = palette.base02;
        }
        {
            from = "#636363";
            to = palette.base03;
        }
        {
            from = "#757575";
            to = palette.base03;
        }
        {
            from = "#b3b3b3";
            to = palette.base04;
        }
        {
            from = "#d9b98c";
            to = palette.base06;
        }
        {
            from = "#ffffff";
            to = palette.base05;
        }
        {
            from = "#fae2c8";
            to = palette.base07;
        }
        {
            from = "#ff9e3b";
            to = palette.base0A;
        }
        {
            from = "#ffb86c";
            to = palette.base09;
        }
        {
            from = "#f08d49";
            to = palette.base09;
        }
        {
            from = "#ff6b6b";
            to = palette.base08;
        }
        {
            from = "#b9d665";
            to = palette.base0B;
        }
        {
            from = "#aee6d6";
            to = palette.base0C;
        }
        {
            from = "#9cd9e6";
            to = palette.base0D;
        }
        {
            from = "#eba4be";
            to = palette.base0E;
        }
    ];

    replacePalette = source:
        lib.replaceStrings
        (map (mapping: mapping.from) colorMappings)
        (map (mapping: "#${mapping.to}") colorMappings)
        source;

    stylesheet =
        pkgs.writeText "catthode-stylix.qss"
        (replacePalette (builtins.readFile "${inputs.catthode}/src/stylesheet.qss"));

    configJson =
        pkgs.writeText "catthode-stylix.json"
        (replacePalette (builtins.readFile "${inputs.catthode}/src/config.json"));

    resources = pkgs.writeText "catthode-stylix.qrc" ''
        <RCC>
            <qresource prefix="/uitheme">
                <file alias="stylesheet.qss">${stylesheet}</file>
                <file alias="config.json">${configJson}</file>
            </qresource>
        </RCC>
    '';

    theme =
        pkgs.runCommand "catthode-stylix.qbtheme" {
            nativeBuildInputs = [pkgs.qt6.qtbase];
        } ''
            mkdir -p "$out/share/qBittorrent/themes"
            mkdir -p "$out/share/licenses/catthode-qbittorrent"

            ${pkgs.qt6.qtbase}/libexec/rcc --binary -no-compress ${resources} \
                -o "$out/share/qBittorrent/themes/stylix.qbtheme"

            cp ${inputs.catthode}/LICENSE \
                "$out/share/licenses/catthode-qbittorrent/LICENSE"
        '';

    configureTheme = pkgs.writeText "configure-qbittorrent-theme.py" ''
        import os
        import stat
        import sys
        from pathlib import Path

        config_path = Path(sys.argv[1])
        theme_path = Path(sys.argv[2])

        if not theme_path.is_file():
            raise SystemExit(f"Theme file not found: {theme_path}")

        config_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            original = config_path.read_text(encoding="utf-8")
        except FileNotFoundError:
            original = ""

        lines = original.splitlines()

        start = next(
            (i for i, line in enumerate(lines)
             if line.strip() == "[Preferences]"),
            None
        )

        if start is None:
            if lines and lines[-1]:
                lines.append("")
            lines.append("[Preferences]")
            start = len(lines) - 1

        end = next(
            (i for i in range(start + 1, len(lines))
             if lines[i].strip().startswith("[")
             and lines[i].strip().endswith("]")),
            len(lines)
        )

        section = lines[start + 1:end]

        updates = [
            ("General\\UseCustomUITheme", "true"),
            ("General\\CustomUIThemePath", str(theme_path)),
        ]

        for key, value in updates:
            updated = []
            found = False

            for line in section:
                if "=" in line and line.split("=", 1)[0].strip() == key:
                    if not found:
                        updated.append(f"{key}={value}")
                        found = True
                else:
                    updated.append(line)

            if not found:
                updated.append(f"{key}={value}")

            section = updated

        lines = lines[:start + 1] + section + lines[end:]
        result = "\n".join(lines).rstrip("\n") + "\n"

        if result == original:
            sys.exit(0)

        mode = (
            stat.S_IMODE(config_path.stat().st_mode)
            if config_path.exists()
            else 0o600
        )

        temporary = config_path.with_name(config_path.name + ".hm-tmp")
        temporary.write_text(result, encoding="utf-8")
        temporary.chmod(mode)
        os.replace(temporary, config_path)
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
                xdg.configFile."qBittorrent/themes/stylix.qbtheme".source = "${theme}/share/qBittorrent/themes/stylix.qbtheme";

                home.activation.enableQbittorrentTheme = lib.hm.dag.entryAfter ["linkGeneration"] ''
                    if ${pkgs.procps}/bin/pgrep -u "$USER" -f '[q]bittorrent' >/dev/null 2>&1; then
                        echo "qBittorrent is running; skipping theme activation. Close it and run nixapply switch again." >&2
                    else
                        run ${pkgs.python3}/bin/python3 ${configureTheme} \
                            ${lib.escapeShellArg "${config.xdg.configHome}/qBittorrent/qBittorrent.conf"} \
                            ${lib.escapeShellArg "${config.xdg.configHome}/qBittorrent/themes/stylix.qbtheme"}
                    fi
                '';
            })
    ];
}
