{...}: {
    programs.broot = {
        enable = true;
        enableBashIntegration = false;
        enableFishIntegration = false;
        enableNushellIntegration = false;
        enableZshIntegration = false;
        settings.default_flags = "gh";
    };
}
