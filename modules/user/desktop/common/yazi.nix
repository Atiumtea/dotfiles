{pkgs, ...}: {
    programs.yazi = {
        plugins = {
            git = {
                package = pkgs.yaziPlugins.git;
                setup = true;
                settings.order = 1500;
            };

            smart-enter = pkgs.yaziPlugins.smart-enter;
            smart-paste = pkgs.yaziPlugins.smart-paste;
            jump-to-char = pkgs.yaziPlugins.jump-to-char;
            smart-filter = pkgs.yaziPlugins.smart-filter;
        };

        keymap.mgr.prepend_keymap = [
            {
                on = ["l"];
                run = "plugin smart-enter";
                desc = "Open file or enter directory";
            }
            {
                on = ["p"];
                run = "plugin smart-paste";
                desc = "Paste into hovered directory";
            }
            {
                on = ["f"];
                run = "plugin jump-to-char";
                desc = "Jump to file by character";
            }
            {
                on = ["F"];
                run = "plugin smart-filter";
                desc = "Smart filter";
            }
        ];

        settings.plugin.prepend_fetchers = [
            {
                url = "*";
                run = "git";
                group = "git";
            }
            {
                url = "*/";
                run = "git";
                group = "git";
            }
        ];

        theme.git = {
            unknown_sign = "! ";
            ignored_sign = "i ";
            untracked_sign = "? ";
            unstaged_sign = "M ";
            staged_sign = "S ";
            added_sign = "A ";
            deleted_sign = "D ";
            updated_sign = "U ";
        };
    };
}
