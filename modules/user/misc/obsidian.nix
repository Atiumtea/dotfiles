{
    config,
    lib,
    ...
}: {
    options = {
        userSettings = {
            obsidian.enable = lib.mkEnableOption "Obsidian";
        };
    };

    config = lib.mkIf config.userSettings.obsidian.enable {
        programs.obsidian = {
            enable = true;
            vaults = {
                notes = {
                    enable = true;
                    target = "documents/obsidian/notes";
                    settings = {
                        corePlugins = [
                            "daily-notes"
                            "templates"
                            "graph"
                            "backlink"
                            "outline"
                            "tag-pane"
                        ];
                    };
                };
            };
        };
    };
}
