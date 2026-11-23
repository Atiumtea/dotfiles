{
    lib,
    stdenvNoCC,
    fetchurl,
}: let
    revision = "05ff264c403bafb04974d2e08de38c585c2636ac";

    regular = fetchurl {
        url = "https://raw.githubusercontent.com/lwhitelaw/Swanston/${revision}/Swanston.ttf";
        hash = "sha256-Ne3oUismK8tHOyylNOJ/sarEV5262ZYuwOAyiwIyLs4=";
    };

    bold = fetchurl {
        url = "https://raw.githubusercontent.com/lwhitelaw/Swanston/${revision}/Swanston-Bold.ttf";
        hash = "sha256-geZ51tBsHDYff8cwbqx8iaPMkCdxJoTz8PgddGgP7GA=";
    };
in
    stdenvNoCC.mkDerivation {
        pname = "swanston";
        version = "2023-09-09";
        dontUnpack = true;

        installPhase = ''
            runHook preInstall

            install -Dm644 ${regular} "$out/share/fonts/truetype/Swanston.ttf"
            install -Dm644 ${bold} "$out/share/fonts/truetype/Swanston-Bold.ttf"

            runHook postInstall
        '';

        meta = {
            description = "Monospaced outline font inspired by bitmap terminal fonts";
            homepage = "https://github.com/lwhitelaw/Swanston";
            license = lib.licenses.ofl;
            platforms = lib.platforms.all;
        };
    }
