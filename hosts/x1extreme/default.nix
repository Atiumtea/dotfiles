{
    config,
    lib,
    inputs,
    ...
}: {
    # add additional imports here if needed
    imports = [
        ./configuration.nix
        ./hardware-configuration-additional.nix

        # Hardware configuration for Lenovo ThinkPad X1 Extreme Gen 2
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-extreme-gen2
    ];

    config = {
        # do not change; automatically imports everything needed
        home-manager.users = lib.listToAttrs (map (user: {
            name = user.name;
            value = {
                # Pass the current user's name to the Home Manager modules.
                # modules/user/shells/default.nix requires the `username` argument.
                _module.args.username = user.name;

                imports = [
                    ./home-${user.name}.nix
                    ../../modules/user
                ];
            };
        })
        config.hostSettings.users);
    };
}
