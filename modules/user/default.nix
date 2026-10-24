{...}: {
    imports = [
        ./home.nix
        ./git.nix
        ./security.nix
        ./xdg.nix

        ./browsers
        ./desktop
        ./editors
        ./misc
        ./shells
        ./styling
        ./terminals
        ./scripts
    ];
}
