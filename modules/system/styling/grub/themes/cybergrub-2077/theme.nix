{
    stdenvNoCC,
    lib,
    fetchFromGitHub,
    logo ? "samurai",
    ...
}: let
    version = "cf633b63db74d1f0e3d2d8591247a5aab63c9961";

    src = fetchFromGitHub {
        owner = "adnksharp";
        repo = "CyberGRUB-2077";
        rev = "${version}";
        hash = "sha256-OGqmHL2qqtWS47GguEklp9S3wU/EwzPEyKJQyCFOKsM=";
    };

    logoFile = lib.escapeShellArg "img/logos/${logo}.png";
    logoName = lib.escapeShellArg logo;
in
    stdenvNoCC.mkDerivation {
        inherit version src;

        pname = "cybergrub-grub-theme";

        installPhase = ''
            runHook preInstall

            if [ ! -f ${logoFile} ]; then
                printf 'Unknown CyberGRUB logo: %s\n' ${logoName} >&2

                echo "Available logos:" >&2

                for candidate in img/logos/*.png; do
                    candidate="''${candidate##*/}"
                    printf '  %s\n' "''${candidate%.png}" >&2
                done

                exit 1
            fi

            dir="$out/share/grub/themes/cybergrub-2077"

            mkdir -p "$dir"
            cp -r CyberGRUB-2077/* "$dir"
            cp ${logoFile} "$dir/logo.png"

            runHook postInstall
        '';

        meta = {
            description = "GRUB Bootloader Theme Inspired by Cyberpunk 2077.";
            homepage = "https://github.com/adnksharp/CyberGRUB-2077";
            license = lib.licenses.unlicense;
        };
    }
