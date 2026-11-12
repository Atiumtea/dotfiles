
{
    config,
    lib,
    ...
}: {
    config.programs.nixvim = lib.mkIf config.userSettings.nixvim.enable {
        plugins.treesitter = {
            enable = true;
            nixvimInjections = true;

            highlight.enable = true;
            indent.enable = true;
            folding.enable = true;

            grammarPackages =
                with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
                    c
                    cpp
                    lua
                    luadoc
                    rust
                    nix
                    python
                    asm
                    nasm
                    html
                    superhtml
                    css
                    javascript
                    typescript
                    sql
                    bash
                    vim
                    vimdoc

                    markdown
                    markdown-inline
                    typst
                    latex

                    json
                    json5
                    yaml
                    toml
                    xml

                    cmake
                    make
                    llvm
                    linkerscript
                    terraform
                    helm

                    zsh
                    proto
                    dockerfile

                    gitignore
                    gitattributes
                    git-rebase
                    gitcommit
                ];
        };
    };
}
