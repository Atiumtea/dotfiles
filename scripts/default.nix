{
    pkgs,
    lib,
    ...
}: {
    home.packages = [
        (pkgs.writeShellApplication {
            name = "nixapply";
            runtimeInputs = with pkgs; [nh alejandra nvd git coreutils];
            text = builtins.readFile ../../../scripts/apply-boot.sh;
            # если shellcheck будет ругаться:
            # excludeShellChecks = [ "SC2154" ];
        })

        (pkgs.writeShellApplication {
            name = "nixsnap";
            runtimeInputs = with pkgs; [wl-clipboard git jq nix coreutils];
            text = builtins.readFile ../../../scripts/snapshot-config.sh;
        })
    ];
}
