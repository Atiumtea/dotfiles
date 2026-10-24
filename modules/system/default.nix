{...}: {
    imports = [
        ./configuration.nix

        ./audio.nix
        ./gaming.nix
        ./users.nix
        ./virtualization.nix

        ./desktop
        ./hardware
        ./iriun
        ./kernel
        ./postgresql
        ./sddm
        ./security
        ./styling
    ];
}
