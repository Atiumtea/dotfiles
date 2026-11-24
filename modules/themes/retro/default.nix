{
    scheme = "RetroPC";
    slug = "retro";
    author = "Ron Dilley, adapted by Atiumtea (https://github.com/rondilley)";
    description = "Dark amber CRT palette with distinct semantic ANSI colors";
    polarity = "dark";
    background = ./dunes.jpg;
    backgroundHash = "";

    base00 = "0a0a08"; # Background
    base01 = "1a1612"; # Secondary background
    base02 = "63491f"; # Selection
    base03 = "9a7b45"; # Muted foreground
    base04 = "b58a49"; # Dim foreground
    base05 = "d6ad68"; # Foreground
    base06 = "ffd27a"; # Light foreground
    base07 = "f3d28a"; # Normal white

    # Distinct semantic hues keep ANSI colors and status accents readable.
    base08 = "e56b4e"; # Red
    base09 = "e99545"; # Orange
    base0A = "e9c66b"; # Yellow
    base0B = "a7b96a"; # Green
    base0C = "63aaa2"; # Cyan
    base0D = "6e9fbe"; # Blue / Hyprland accent
    base0E = "a987bd"; # Violet
    base0F = "a87950"; # Brown
}
