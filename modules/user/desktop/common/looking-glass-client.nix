{
    stdenv,
    lib,
    src,
    cmake,
    pkg-config,
    wayland-scanner,
    gawk,
    binutils,
    fontconfig,
    freefont_ttf,
    fuse3,
    gmp,
    spice-protocol,
    nettle,
    libunwind,
    elfutils,
    libGL,
    libx11,
    libxfixes,
    libxi,
    libxscrnsaver,
    libxinerama,
    libxcursor,
    libxpresent,
    libxrandr,
    libxkbcommon,
    wayland,
    wayland-protocols,
    pipewire,
    pulseaudio,
    libsamplerate,
    usbredir,
}:
stdenv.mkDerivation {
    pname = "looking-glass-client";
    version = "B8-rc1";

    inherit src;

    nativeBuildInputs = [
        cmake
        pkg-config
        wayland-scanner
        gawk
        binutils
    ];

    buildInputs = [
        fontconfig
        freefont_ttf
        fuse3
        gmp
        spice-protocol
        nettle
        libunwind
        elfutils
        libGL

        libx11
        libxfixes
        libxi
        libxscrnsaver
        libxinerama
        libxcursor
        libxpresent
        libxrandr
        libxkbcommon

        wayland
        wayland-protocols

        pipewire
        pulseaudio
        libsamplerate
        usbredir
    ];

    postUnpack = ''
        echo "${version}" > source/VERSION
        export sourceRoot="source/client"
    '';

    cmakeFlags = [
        "-DOPTIMIZE_FOR_NATIVE=OFF"
    ];

    meta = {
        description = "Looking Glass B8 Linux client";
        homepage = "https://looking-glass.io/";
        license = lib.licenses.gpl2Plus;
        mainProgram = "looking-glass-client";
        platforms = ["x86_64-linux"];
    };
}
