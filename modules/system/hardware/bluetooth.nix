{
    lib,
    config,
    ...
}: {
    options = {
        hostSettings = {
            hardware.bluetooth.enable = lib.mkEnableOption "Bluetooth support";
        };
    };

    config = lib.mkIf config.hostSettings.hardware.bluetooth.enable {
        hardware.bluetooth = {
            enable = true;
            powerOnBoot = true;
            settings = {
                General = {
                    Experimental = true;
                    FastConnectable = true;
                };
                Policy = {
                    AutoEnable = true;
                };
            };
        };

        services.blueman.enable = true;
    };
}
