# NixVim translation of the upstream RetroPC Nightfox/Carbonfox preset.
# Source: https://github.com/rondilley/omarchy-retropc-theme/blob/main/neovim.lua
{
    nightfox = {
        enable = true;
        flavor = "carbonfox";
        settings = {
            options = {
                terminal_colors = true;
                dim_inactive = true;
                styles = {
                    comments = "italic";
                    functions = "bold";
                    keywords = "bold";
                };
                modules = {
                    neotree = true;
                    treesitter = true;
                };
            };

            palettes.carbonfox = {
                bg0 = "#0A0A08";
                bg1 = "#0A0A08";
                bg2 = "#1A1612";
                bg3 = "#2A1F00";
                bg4 = "#2A1F00";
                fg0 = "#FFCC00";
                fg1 = "#FFB000";
                fg2 = "#CC9900";
                fg3 = "#996600";
                sel0 = "#2A1F00";
                sel1 = "#554200";
                comment = "#805500";

                red = {
                    base = "#FF8800";
                    bright = "#FF9B29";
                    dim = "#FF6600";
                };
                orange = {
                    base = "#FFBB00";
                    bright = "#FFCC00";
                    dim = "#D69D00";
                };
                yellow = {
                    base = "#FFCC00";
                    bright = "#FFD633";
                    dim = "#FFB000";
                };
                white = {
                    base = "#FFB000";
                    bright = "#FFCC00";
                    dim = "#CC9900";
                };
                black = {
                    base = "#2A1F00";
                    bright = "#805500";
                    dim = "#1A1612";
                };
                green = {
                    base = "#CC9900";
                    bright = "#D4AA00";
                    dim = "#996600";
                };
                cyan = {
                    base = "#FFAA00";
                    bright = "#FFBB00";
                    dim = "#CC8800";
                };
                blue = {
                    base = "#CC9900";
                    bright = "#D4AA00";
                    dim = "#996600";
                };
                magenta = {
                    base = "#FF9900";
                    bright = "#FFAA00";
                    dim = "#CC7700";
                };
                pink = {
                    base = "#FFAA00";
                    bright = "#FFBB00";
                    dim = "#CC8800";
                };

                lualine_normal_bg = "#FFBB00";
                lualine_insert_bg = "#FF8800";
                lualine_visual_bg = "#FF9900";
                lualine_command_bg = "#FFBB00";
                lualine_inactive_bg = "#181813";
                ts_parameter = "#FFAA00";
                ts_property = "#FFB000";
            };

            specs.carbonfox = {
                syntax = {
                    keyword = "red";
                    conditional = "red";
                    statement = "red";
                    func = "orange";
                    string = "orange.dim";
                    number = "orange";
                    operator = "yellow";
                    variable = "white";
                    ident = "white.dim";
                    const = "white";
                    type = "white";
                    field = "white.dim";
                    comment = "comment";
                };
                diag = {
                    error = "red";
                    warn = "red";
                    info = "cyan";
                    hint = "magenta";
                };
            };

            groups.all = {
                Whitespace.fg = "palette.black.bright";
                NonText.fg = "palette.black.bright";
                IncSearch.bg = "palette.sel1";
                CursorLine.bg = "palette.bg2";
                Normal.fg = "palette.fg1";

                NoiceCmdlinePopupBorder.fg = "palette.fg3";
                NoiceCmdlinePopupTitle = {
                    fg = "palette.fg3";
                    style = "bold";
                };
                NoiceCmdlinePopupBorderSearch.fg = "palette.fg3";
                NoiceCmdlinePopupTitleSearch = {
                    fg = "palette.fg3";
                    style = "bold";
                };
                NoiceCmdLineIcon.fg = "palette.red";

                NeoTreeNormal.bg = "palette.bg0";
                NeoTreeNormalNC.link = "NeoTreeNormal";
                NeoTreeDirectoryName.fg = "palette.fg3";
                NeoTreeDirectoryIcon.fg = "palette.fg3";
                NeoTreeRootName = {
                    fg = "palette.orange";
                    style = "bold";
                };
                NeoTreeGitAdded.fg = "palette.green";
                NeoTreeGitModified.fg = "palette.yellow";
                NeoTreeGitDeleted.fg = "palette.red";
                NeoTreeGitIgnored.fg = "palette.comment";
                NeoTreeC = {
                    fg = "palette.orange";
                    bg = "palette.sel0";
                };

                SnacksDashboardHeader.fg = "palette.fg3";
                SnacksDashboardIcon.fg = "palette.fg1";
                SnacksDashboardDir.fg = "palette.orange";
                SnacksDashboardFile.fg = "palette.fg3";
                SnacksDashboardFooter.fg = "palette.fg3";
                SnacksDashboardKey.fg = "palette.orange";
                SnacksDashboardDesc.fg = "palette.fg1";
                SnacksDashboardSpecial.fg = "palette.fg1";

                "@comment" = {
                    fg = "palette.comment";
                    style = "italic";
                };
                "@keyword" = {
                    fg = "palette.red";
                    style = "bold";
                };
                "@keyword.function" = {
                    fg = "palette.red";
                    style = "bold";
                };
                "@keyword.operator" = {
                    fg = "palette.red";
                    style = "bold";
                };
                "@function" = {
                    fg = "palette.orange";
                    style = "bold";
                };
                "@function.builtin" = {
                    fg = "palette.orange";
                    style = "bold";
                };
                "@function.call".fg = "palette.orange";
                "@string".fg = "palette.orange";
                "@number".fg = "palette.orange";
                "@operator".fg = "palette.yellow";
                "@variable".fg = "palette.white";
                "@constant".fg = "palette.white";
                "@type".fg = "palette.white.dim";
                "@variable.parameter" = {
                    fg = "palette.ts_parameter";
                    style = "italic";
                };
                "@property".fg = "palette.ts_property";
                "@field".fg = "palette.ts_property";
            };
        };
    };

    lualine = {
        normal = {
            a = {
                fg = "#0A0A08";
                bg = "#FFBB00";
                gui = "bold";
            };
            b = {
                fg = "#FFB000";
                bg = "#181813";
            };
            c = {
                fg = "#CC9900";
                bg = "#181813";
            };
        };
        insert = {
            a = {
                fg = "#0A0A08";
                bg = "#FF8800";
                gui = "bold";
            };
            b = {
                fg = "#FFB000";
                bg = "#181813";
            };
            c = {
                fg = "#CC9900";
                bg = "#181813";
            };
        };
        visual = {
            a = {
                fg = "#0A0A08";
                bg = "#FF9900";
                gui = "bold";
            };
            b = {
                fg = "#FFB000";
                bg = "#181813";
            };
            c = {
                fg = "#CC9900";
                bg = "#181813";
            };
        };
        command = {
            a = {
                fg = "#0A0A08";
                bg = "#FFBB00";
                gui = "bold";
            };
            b = {
                fg = "#FFB000";
                bg = "#181813";
            };
            c = {
                fg = "#CC9900";
                bg = "#181813";
            };
        };
        inactive = {
            a = {
                fg = "#996600";
                bg = "#181813";
            };
            b = {
                fg = "#996600";
                bg = "#181813";
            };
            c = {
                fg = "#805500";
                bg = "#181813";
            };
        };
    };
}
