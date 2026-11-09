{
    inputs,
    lib,
    pkgs,
}:
pkgs.stdenvNoCC.mkDerivation {
    pname = "hyproled";
    version = "0.4.0-dev";

    src = inputs.hyproled;
    dontUnpack = true;

    nativeBuildInputs = [pkgs.makeWrapper];

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
}
