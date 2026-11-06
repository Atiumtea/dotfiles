{
    config,
    inputs,
    lib,
    osConfig,
    pkgs,
    ...
}: let
    hyproledPackage = pkgs.stdenvNoCC.mkDerivation {
        pname = "hyproled";
        version = "0.3.0-dev";
        src = inputs.hyproled;
        nativeBuildInputs = [pkgs.makeWrapper];
        dontBuild = true;

        installPhase = ''
            install -Dm755 "$src/hyproled" "$out/bin/hyproled"
            install -d "$out/share/hyproled/icons"
            cp -r "$src/assets/icons/." "$out/share/hyproled/icons/"

            wrapProgram "$out/bin/hyproled" \
                --prefix PATH : "${lib.makeBinPath (with pkgs; [
                bash
                coreutils
                jq
                util-linux
                brightnessctl
                hyprland
            ])}"
        '';
    };
in {
    config = lib.mkIf osConfig.hostSettings.desktop.enable {
        home.packages = [hyproledPackage];

        programs.waybar = {
            enable = true;

            settings = {
                mainBar = {
                    layer = "top";
                    margin-top = 4;
                    margin-right = 4;
                    margin-bottom = 0;
                    margin-left = 4;

                    modules-left = [
                        "custom/launcher"
                        "backlight"
                        "wireplumber"
                        "cpu"
                        "mpris"
                    ];

                    modules-center = [
                        "hyprland/workspaces"
                        "clock"
                    ];

                    modules-right = [
                        "wlr/taskbar"
                        "hyprland/language"
                        "custom/bluetooth"
                        "network"
                        "memory"
                        "custom/hyproled"
                        "tray"
                        "battery"
                    ];

                    "hyprland/language" = {
                        format = "{}";
                        format-en = "EN";
                        format-ru = "RU";
                        tooltip-format = "{long}";
                    };

                    wireplumber = {
                        tooltip = false;
                        scroll-step = 5;
                        format = "{icon}  {volume}%";
                        format-muted = "󰝟 {volume}%";
                        on-click = "pavucontrol";
                        format-icons = ["" "" ""];
                    };

                    network = {
                        tooltip = true;
                        format-wifi = " ";
                        rotate = 0;
                        format-ethernet = "󰈀 ";
                        tooltip-format = ''
                            Network: <big><b>{essid}</b></big>
                            Signal strength: <b>{signaldBm}dBm ({signalStrength}%)</b>
                            Frequency: <b>{frequency}MHz</b>
                            Interface: <b>{ifname}</b>
                            IP: <b>{ipaddr}/{cidr}</b>
                            Gateway: <b>{gwaddr}</b>
                            Netmask: <b>{netmask}</b>
                        '';
                        format-linked = "󰈀 {ifname} (No IP)";
                        format-disconnected = "󰖪 ";
                        tooltip-format-disconnected = "Disconnected";
                        interval = 2;
                        on-click = "kitty -- nmtui";
                    };

                    backlight = {
                        device = "intel_backlight";
                        rotate = 0;
                        format = "{icon} {percent}%";
                        format-icons = [""];
                        on-scroll-up = "brightnessctl set 1%+";
                        on-scroll-down = "brightnessctl set 1%-";
                        min-length = 6;
                    };

                    battery = {
                        states = {
                            good = 95;
                            warning = 30;
                            critical = 20;
                        };
                        format = "{icon} {capacity}%";
                        rotate = 0;
                        format-charging = " {capacity}%";
                        format-plugged = " {capacity}%";
                        format-alt = "{time} {icon}";
                        format-icons = [
                            "󰂎"
                            "󰁺"
                            "󰁻"
                            "󰁼"
                            "󰁽"
                            "󰁾"
                            "󰁿"
                            "󰂀"
                            "󰂁"
                            "󰂂"
                            "󰁹"
                        ];
                    };

                    clock = {
                        format = "{:%H:%M}";
                        format-alt = "{:%m-%d-%Y}";
                        tooltip = false;
                    };

                    cpu = {
                        format = " {usage}%";
                        on-click = "kitty -- btop";
                        tooltip = true;
                    };

                    tray = {
                        icon-size = 16;
                        rotate = 0;
                        spacing = 5;
                    };

                    memory = {
                        interval = 30;
                        format = "  {used:0.1f}G/{total:0.1f}G";
                        max-length = 20;
                    };

                    "custom/launcher" = {
                        format = " ";
                    };

                    "custom/bluetooth" = {
                        format = " {}";
                        exec = "${config.xdg.configHome}/waybar/bluetooth-display.sh";
                        interval = 10;
                        return-type = "plain";
                        tooltip = false;
                        max-length = 25;
                    };

                    "custom/hyproled" = {
                        exec = "${hyproledPackage}/bin/hyproled --status";
                        return-type = "json";
                        interval = 1;
                        signal = 10;
                        format = " ";
                        tooltip = true;
                    };

                    mpris = {
                        format = "{player_icon}  {dynamic}";
                        format-paused = "{status_icon} {dynamic}";
                        format-stopped = "";
                        ignore-list = ["vesktop"];
                        player-icons = {
                            brave = "";
                            default = "";
                            spotify = "";
                            vlc = "";
                            mpv = "";
                        };
                        status-icons = {
                            paused = "▶";
                            playing = "⏸";
                        };
                        max-length = 50;
                        tooltip = true;
                        interval = 1;
                    };

                    "hyprland/workspaces" = {
                        format = "{icon}";
                        format-icons = {
                            "1" = "I";
                            "2" = "II";
                            "3" = "III";
                            "4" = "IV";
                            "5" = "V";
                            "6" = "VI";
                            "7" = "VII";
                            "8" = "VIII";
                            "9" = "IX";
                            "10" = "X";
                            default = "?";
                        };
                        active = "";
                        "sort-by-number" = true;
                    };

                    "wlr/taskbar" = {
                        format = "{icon}";
                        icon-size = 16;
                        # icon-theme = "${config.gtk.iconTheme.name}"; # NOTE: null ;(
                        tooltip-format = "{title}";
                        on-click = "activate";
                        on-click-middle = "close";
                        ignore-list = ["${config.userSettings.terminals.defaultTerminal}" "cava"];
                        markup = true;
                        "all-outputs" = false;
                    };
                };
            };

            style = lib.mkAfter (
                lib.replaceStrings
                ["@HYPROLED_ICON_DIR@"]
                ["${hyproledPackage}/share/hyproled/icons"]
                (builtins.readFile ./waybar.css)
            );
        };

        xdg.configFile."waybar/bluetooth-display.sh" = {
            source = ./waybar-bluetooth-display.sh;
            executable = true;
        };

        # we do our own
        stylix.targets.waybar.addCss = false;
    };
}
