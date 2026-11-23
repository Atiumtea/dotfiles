{
    lib,
    stdenvNoCC,
    fetchFromGitHub,
    cbmp,
    clickgen,
    baseColor,
    outlineColor,
    watchBackgroundColor,
}:
stdenvNoCC.mkDerivation {
    pname = "bibata-retropc";
    version = "2.0.7";

    src = fetchFromGitHub {
        owner = "ful1e5";
        repo = "Bibata_Cursor";
        rev = "v2.0.7";
        hash = "sha256-kIKidw1vditpuxO1gVuZeUPdWBzkiksO/q2R/+DUdEc=";
    };

    nativeBuildInputs = [
        cbmp
        clickgen
    ];

    dontConfigure = true;

    postPatch = ''
        substituteInPlace svg/original/left_ptr.svg \
            --replace-fail 'stroke-width="17"' 'stroke-width="13"'

        substituteInPlace svg/original/xterm.svg \
            --replace-fail 'stroke-width="17"' 'stroke-width="9"'
    '';

    buildPhase = ''
        runHook preBuild

        mkdir -p bitmaps

        cbmp \
            --dir svg/original \
            --out bitmaps/Bibata-RetroPC \
            --baseColor "#${baseColor}" \
            --outlineColor "#${outlineColor}" \
            --watchBackgroundColor "#${watchBackgroundColor}"

        ctgen configs/normal/x.build.toml \
            -p x11 \
            -d bitmaps/Bibata-RetroPC \
            -n Bibata-RetroPC \
            -c 'RetroPC palette with refined cursor outlines'

        runHook postBuild
    '';

    installPhase = ''
        runHook preInstall

        install -dm 0755 "$out/share/icons"
        cp -R themes/Bibata-RetroPC "$out/share/icons/"

        install -Dm644 LICENSE \
            "$out/share/licenses/bibata-retropc/LICENSE"

        runHook postInstall
    '';

    meta = {
        description = "Bibata XCursor theme adapted for RetroPC";
        homepage = "https://github.com/ful1e5/Bibata_Cursor";
        license = lib.licenses.gpl3Only;
        platforms = lib.platforms.linux;
    };
}
