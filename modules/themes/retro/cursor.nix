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

        # Reduce resize cursor artwork while preserving its hotspot.
        shrink_cursor_path() {
            local file="$1" x="$2" y="$3"
            local transform="translate($x $y) scale(0.80) translate(-$x -$y)"

            sed -i \
                "0,/<path d=/s#<path d=#<path transform=\"$transform\" d=#" \
                "$file"
        }

        shrink_corner_cursor() {
            local file="$1" x="$2" y="$3"
            local transform="translate($x $y) scale(0.80) translate(-$x -$y)"

            # Scale the corner body and the arrow overlay together.
            sed -i \
                "0,/<path d=/s#<path d=#<path transform=\"$transform\" d=#" \
                "$file"

            sed -i \
                "0,/<g filter=/s#<g filter=#<g transform=\"$transform\" filter=#" \
                "$file"
        }

        shrink_cursor_path svg/original/top_side.svg 128 23
        shrink_cursor_path svg/original/bottom_side.svg 129 234
        shrink_cursor_path svg/original/left_side.svg 21 128
        shrink_cursor_path svg/original/right_side.svg 233 128

        shrink_corner_cursor svg/original/top_left_corner.svg 29 24
        shrink_corner_cursor svg/original/top_right_corner.svg 229 24
        shrink_corner_cursor svg/original/bottom_left_corner.svg 26 232
        shrink_corner_cursor svg/original/bottom_right_corner.svg 229 232
    '';

    buildPhase = ''
        runHook preBuild

        mkdir -p bitmaps

        CI=1 NO_COLOR=1 cbmp \
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
