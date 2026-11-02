{...}: {
    imports = [
        ./configuration.nix

        ./audio.nix
        ./gaming.nix
        ./users.nix
        ./virtualization.nix

        ./desktop
        ./hardware
        ./kernel
        ./postgresql
        ./sddm
        ./security
        ./styling
    ];
}
