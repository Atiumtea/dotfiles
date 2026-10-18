{
    pkgs,
    lib,
    ...
}: {
    home.packages = [
        (pkgs.writeShellScriptBin "nixapply" ''
            export PATH="${lib.makeBinPath (with pkgs; [nh alejandra nvd git coreutils])}:$PATH"
            exec ${../../../scripts/apply-boot.sh} "$@"
        '')

        (pkgs.writeShellScriptBin "nixsnap" ''
            export PATH="${lib.makeBinPath (with pkgs; [wl-clipboard git jq nix coreutils])}:$PATH"
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
}
