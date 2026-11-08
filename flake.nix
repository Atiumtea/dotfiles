{
    description = "Atiumtea's NixOS";

    outputs = inputs @ {...}: let
        # NOTE: hard-coded for now
        system = "x86_64-linux";

        lib = inputs.nixpkgs.lib;
        libM = lib // import ./lib {lib = lib;};

        # Only expose the configurations we want to maintain.
        hosts = [
            "x1extreme"
        ];
    in {
        nixosConfigurations = builtins.listToAttrs (map (host: {
            name = host;
            value = lib.nixosSystem {
                inherit system;

                modules = [
                    {
                        nixpkgs = {
                            config = {allowUnfree = true;};
                            overlays = [inputs.nix-firefox-addons.overlays.default];
                        };
                    }

                    {
                        nixpkgs.overlays = [
                            inputs.pi-nix.overlays.default
                        ];
                    }

                    # host-specific configuration
                    {config.networking.hostName = host;}
                    ./hosts/${host}

                    # common configuration
                    ./modules/system

                    # Declarative Flatpak application management
                    inputs.nix-flatpak.nixosModules.nix-flatpak

                    # inputs.sops-nix.nixosModules.sops  # TODO: re-enable when Go 1.26 lands in nixpkgs
                    inputs.home-manager.nixosModules.home-manager
                    {
                        home-manager.useGlobalPkgs = true;
                        home-manager.useUserPackages = true;
                        home-manager.backupFileExtension = "hm-backup";

                        home-manager.extraSpecialArgs = {
                            inherit system;
                            inherit libM;
                            inherit inputs;
                        };
                    }
                ];

                specialArgs = {
                    inherit system;
                    inherit libM;
                    inherit inputs;
                };
            };
        })
        hosts);

        devShells."${system}".default = let
            pkgs = import inputs.nixpkgs {
                inherit system;
                config.allowUnfree = true;
            };
        in
            pkgs.mkShell {
                packages = with pkgs; [
                    nixd
                    inputs.alejandra.defaultPackage.${system}
                    zsh
                    steamcmd
                ];
            };
    };

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        nix-firefox-addons.url = "github:osipog/nix-firefox-addons";

        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        stylix = {
            url = "github:nix-community/stylix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        nixvim = {
            url = "github:nix-community/nixvim";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        niri = {
            url = "github:sodiboo/niri-flake";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        alejandra = {
            url = "github:kamadorueda/alejandra/4.0.0";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        zen-browser = {
            url = "github:0xc000022070/zen-browser-flake";
            inputs = {
                nixpkgs.follows = "nixpkgs";
                home-manager.follows = "home-manager";
            };
        };
        pi-nix = {
            url = "github:takinbo/pi-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        sops-nix = {
            url = "github:Mic92/sops-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        nixos-hardware = {
            url = "github:NixOS/nixos-hardware";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.8.0";

        hyproled = {
            url = "github:Atiumtea/hyproled?ref=feature/pixel-shift";
            flake = false;
        };
    };
}
