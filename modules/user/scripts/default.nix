{
    config,
    pkgs,
    lib,
    ...
}: {
    home.packages = [
        (pkgs.writeShellScriptBin "nixapply" ''
            export PATH="${lib.makeBinPath (with pkgs; [nh alejandra nvd git coreutils nix python3])}:$PATH"
            export NIXSNAP="${../../../scripts/snapshot-config.sh}"
            exec ${../../../scripts/apply-boot.sh} "$@"
        '')

        (pkgs.writeShellScriptBin "nixsnap" ''
            export PATH="${lib.makeBinPath (with pkgs; [wl-clipboard git jq nix coreutils findutils gnused])}:$PATH"
            exec ${../../../scripts/snapshot-config.sh} "$@"
        '')

        (pkgs.writeShellScriptBin "kbtoggle" ''
            cur=$(cat /sys/class/leds/tpacpi::kbd_backlight/brightness)
            if [ "$cur" -eq 0 ]; then
                echo 2 > /sys/class/leds/tpacpi::kbd_backlight/brightness
            else
                echo 0 > /sys/class/leds/tpacpi::kbd_backlight/brightness
            fi
        '')
    ];

    # Keep a lightweight inventory of system generations so removed links
    # remain discoverable in the NixOS Control Center archive.
    systemd.user.services.nixos-generation-history-sync = {
        Unit.Description = "Index NixOS system generations for Control Center";
        Service = {
            Type = "oneshot";
            Environment = [
                "XDG_STATE_HOME=${config.xdg.stateHome}"
                "PATH=${lib.makeBinPath (with pkgs; [nix git])}"
            ];
            ExecStart = "${pkgs.python3}/bin/python3 ${../../../scripts/control-center-generations.py} sync";
        };
    };

    systemd.user.timers.nixos-generation-history-sync = {
        Unit.Description = "Periodically archive NixOS generation inventory";
        Timer = {
            OnBootSec = "2min";
            OnCalendar = "*:0/15";
            Persistent = true;
        };
        Install.WantedBy = ["timers.target"];
    };
}
