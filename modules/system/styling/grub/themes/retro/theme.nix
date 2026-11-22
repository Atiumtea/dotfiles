{
    lib,
    stdenvNoCC,
    src,
    ...
}:
stdenvNoCC.mkDerivation {
    pname = "retrogrub-theme";
    version = "0-unstable";

    inherit src;

    dontUnpack = true;

    installPhase = ''
        runHook preInstall

        install -d "$out/share/grub/themes/retro"
        cp -R "$src"/. "$out/share/grub/themes/retro/"

        runHook postInstall
    '';

    meta = {
        description = "Retro Feanor GRUB theme";
        homepage = "https://github.com/Atiumtea/retrogrub";
        platforms = lib.platforms.linux;
    };
}