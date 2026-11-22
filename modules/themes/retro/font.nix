{stdenvNoCC, ...}:
stdenvNoCC.mkDerivation {
    pname = "bm437-ibm-xga-ai";
    version = "1.0";

    src = ./Bm437_IBM_XGA-AI_12x23.otb;
    dontUnpack = true;

    installPhase = ''
        runHook preInstall

        install -Dm644 "$src" \
            "$out/share/fonts/opentype/Bm437_IBM_XGA-AI_12x23.otb"

        runHook postInstall
    '';
}
