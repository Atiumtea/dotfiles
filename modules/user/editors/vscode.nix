{
    config,
    lib,
    pkgs,
    ...
}: {
    options = {
        userSettings = {
            vscode.enable = lib.mkEnableOption "VS Code";
        };
    };

    config = lib.mkIf config.userSettings.vscode.enable {
        programs.vscode = {
            enable = true;
            profiles.default = {
                extensions = with pkgs.vscode-extensions; [
                    dracula-theme.theme-dracula
                    vscodevim.vim
                    yzhang.markdown-all-in-one
                    jnoortheen.nix-ide
                    arrterian.nix-env-selector
                    editorconfig.editorconfig
                    mkhl.direnv
                ];
            };
        };
    };
}
