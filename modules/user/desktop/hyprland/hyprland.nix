
{
    config,
    osConfig,
    lib,
    ...
}: {
    config = lib.mkIf osConfig.hostSettings.desktop.hyprland.enable {
        wayland.windowManager.hyprland = {
            enable = true;
            package = null;
            portalPackage = null;
            configType = "lua";
            xwayland.enable = true;

            # The settings are generated as hl.config() calls.
            settings.config = {
                general = {
                    gaps_in = 5;
                    gaps_out = 8;
                    border_size = 1;
                    resize_on_border = true;

                    allow_tearing = false;

                    layout = "dwindle";
                };

                # Pixel Shift requires monitor-level redraws.
                # Partial damage leaves stale pixels after texture shifting.
                debug.damage_tracking = 1;

                decoration = {
                    rounding = 10;
                    rounding_power = 2;

                    active_opacity = 1.0;
                    inactive_opacity = 1.0;

                    dim_inactive = true;
                    dim_strength = 0.05;

                    shadow = {
                        enabled = true;
                        range = 4;
                        render_power = 3;
                    };

                    blur = {
                        enabled = true;
                        size = 6;
                        passes = 3;
                        new_optimizations = true;
                        ignore_opacity = true;

                        vibrancy = 0.1696;
                    };
                };

                dwindle = {
                    preserve_split = true;
                };

                master = {
                    new_status = "master";
                };

                misc = {
                    force_default_wallpaper = 0;
                    disable_hyprland_logo = true;
                    disable_splash_rendering = true;

                    mouse_move_enables_dpms = true;
                    key_press_enables_dpms = true;

                    enable_swallow = true;
                    swallow_regex = "^(${config.userSettings.terminals.defaultTerminal})$";
                };

                cursor = lib.mkIf osConfig.hostSettings.hardware.graphics.nvidia.enable {
                    no_hardware_cursors = 1;
                };

                input = {
                    kb_layout = "us, ru";
                    kb_variant = "";
                    kb_model = "";
                    kb_options = "grp:caps_toggle";
                    kb_rules = "";

                    follow_mouse = 1;
                    sensitivity = -0.1;

                    touchpad = {
                        natural_scroll = true;
                    };
                };
            };

            extraConfig = ''
                -- Programs
                local browser = ${builtins.toJSON config.userSettings.browsers.defaultBrowser}
                local terminal = ${builtins.toJSON config.userSettings.terminals.defaultTerminal}
                local fileManager = terminal .. " --class yazi -- yazi"
                local menu = ${builtins.toJSON "rofi -show drun -theme ${config.xdg.configHome}/rofi/launcher.rasi"}
                local powerMenu = ${builtins.toJSON "${config.xdg.configHome}/rofi/powermenu.sh"}
                local setCursor = ${builtins.toJSON "hyprctl setcursor ${config.userSettings.styling.cursor.name} ${toString config.userSettings.styling.cursor.size}"}

                local mainMod = "SUPER"

                -- Environment
                hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
                hl.env("XDG_SESSION_DESKTOP", "Hyprland")

                -- Animation curves
                hl.curve("easeOutQuint", {
                    type = "bezier",
                    points = { { 0.23, 1 }, { 0.32, 1 } },
                })

                hl.curve("easeInOutCubic", {
                    type = "bezier",
                    points = { { 0.65, 0.05 }, { 0.36, 1 } },
                })

                hl.curve("linear", {
                    type = "bezier",
                    points = { { 0, 0 }, { 1, 1 } },
                })

                hl.curve("almostLinear", {
                    type = "bezier",
                    points = { { 0.5, 0.5 }, { 0.75, 1 } },
                })

                hl.curve("quick", {
                    type = "bezier",
                    points = { { 0.15, 0 }, { 0.1, 1 } },
                })

                -- Animations
                hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
                hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
                hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
                hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
                hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
                hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
                hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
                hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
                hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
                hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
                hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
                hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
                hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
                hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
                hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
                hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

                -- Autostart
                hl.on("hyprland.start", function()
                    hl.exec_cmd("waybar")
                    hl.exec_cmd("hyproled --restore")
                    hl.exec_cmd(setCursor)

                    hl.exec_cmd(browser, { workspace = "1 silent" })
                    hl.exec_cmd(terminal, { workspace = "2 silent" })
                end)

                -- Keybindings
                hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
                hl.bind(mainMod .. " + C", hl.dsp.window.close())
                hl.bind(mainMod .. " + M", hl.dsp.exit())
                hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
                hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
                hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))

                -- Switch workspaces with mainMod + [0-9].
                -- Move active windows silently with mainMod + SHIFT + [0-9].
                for i = 1, 10 do
                    local key = i % 10

                    hl.bind(mainMod .. " + " .. key,
                        hl.dsp.focus({ workspace = i }))

                    hl.bind(mainMod .. " + SHIFT + " .. key,
                        hl.dsp.window.move({ workspace = i, follow = false }))
                end

                -- Special workspace (scratchpad).
                hl.bind(mainMod .. " + S",
                    hl.dsp.workspace.toggle_special("magic"))

                hl.bind(mainMod .. " + SHIFT + S",
                    hl.dsp.window.move({ workspace = "special:magic" }))

                -- Scroll through existing workspaces.
                hl.bind(mainMod .. " + mouse_down",
                    hl.dsp.focus({ workspace = "e+1" }))

                hl.bind(mainMod .. " + mouse_up",
                    hl.dsp.focus({ workspace = "e-1" }))

                -- Move windows with J/K and Shift+J/K.
                hl.bind(mainMod .. " + J",
                    hl.dsp.window.move({ direction = "left" }))

                hl.bind(mainMod .. " + K",
                    hl.dsp.window.move({ direction = "right" }))

                hl.bind(mainMod .. " + SHIFT + J",
                    hl.dsp.window.move({ direction = "down" }))

                hl.bind(mainMod .. " + SHIFT + K",
                    hl.dsp.window.move({ direction = "up" }))

                -- Power menu
                hl.bind(mainMod .. " + KP_ENTER",
                    hl.dsp.exec_cmd(powerMenu))

                -- Screenshots
                local saveArea =
                    "grimblast -n -f save area \"$HOME/$(date '+%Y-%m-%d_%H:%M:%S').png\""

                local saveScreen =
                    "grimblast -n -f save screen \"$HOME/$(date '+%Y-%m-%d_%H:%M:%S').png\""

                local editArea =
                    'GRIMBLAST_EDITOR="satty --copy-command wl-copy --actions-on-enter save-to-clipboard,exit --filename " grimblast -f edit area'

                hl.bind("PRINT",
                    hl.dsp.exec_cmd("grimblast -n -f copy area"))

                hl.bind(mainMod .. " + PRINT",
                    hl.dsp.exec_cmd(saveArea))

                hl.bind("SHIFT + PRINT",
                    hl.dsp.exec_cmd(editArea))

                hl.bind("ALT + PRINT",
                    hl.dsp.exec_cmd("grimblast -n -f copy screen"))

                hl.bind(mainMod .. " + ALT + PRINT",
                    hl.dsp.exec_cmd(saveScreen))

                -- Lock screen
                hl.bind(mainMod .. " + L",
                    hl.dsp.exec_cmd("hyprlock"))

                -- Keyboard backlight toggle
                hl.bind(mainMod .. " + F5",
                    hl.dsp.exec_cmd("kbtoggle"))

                -- Music
                hl.bind(mainMod .. " + N",
                    hl.dsp.exec_cmd(terminal .. " --class rmpc -- rmpc"))

                hl.bind(mainMod .. " + SHIFT + N",
                    hl.dsp.exec_cmd(terminal .. " --class cava -- cava"))

                -- Mouse movement and resizing
                hl.bind(mainMod .. " + mouse:272",
                    hl.dsp.window.drag(), { mouse = true })

                hl.bind(mainMod .. " + mouse:273",
                    hl.dsp.window.resize(), { mouse = true })

                -- Multimedia keys
                hl.bind("XF86AudioRaiseVolume",
                    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
                    { locked = true, repeating = true })

                hl.bind("XF86AudioLowerVolume",
                    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
                    { locked = true, repeating = true })

                hl.bind("XF86AudioMute",
                    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
                    { locked = true, repeating = true })

                hl.bind("XF86AudioMicMute",
                    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
                    { locked = true, repeating = true })

                hl.bind("XF86MonBrightnessUp",
                    hl.dsp.exec_cmd("brightnessctl s 10%+"),
                    { locked = true, repeating = true })

                hl.bind("XF86MonBrightnessDown",
                    hl.dsp.exec_cmd("brightnessctl s 10%-"),
                    { locked = true, repeating = true })

                -- Keyboard backlight
                hl.bind("XF86KbdBrightnessUp",
                    hl.dsp.exec_cmd("brightnessctl -d tpacpi::kbd_backlight set 100%"),
                    { locked = true, repeating = true })

                hl.bind("XF86KbdBrightnessDown",
                    hl.dsp.exec_cmd("brightnessctl -d tpacpi::kbd_backlight set 0%"),
                    { locked = true, repeating = true })

                -- Media keys
                hl.bind("XF86AudioNext",
                    hl.dsp.exec_cmd("playerctl next"),
                    { locked = true })

                hl.bind("XF86AudioPause",
                    hl.dsp.exec_cmd("playerctl play-pause"),
                    { locked = true })

                hl.bind("XF86AudioPlay",
                    hl.dsp.exec_cmd("playerctl play-pause"),
                    { locked = true })

                hl.bind("XF86AudioPrev",
                    hl.dsp.exec_cmd("playerctl previous"),
                    { locked = true })

                -- Window rules
                hl.window_rule({
                    name = "suppress-maximize-events",
                    match = { class = ".*" },
                    suppress_event = "maximize",
                })

                -- Fix some dragging issues with XWayland.
                hl.window_rule({
                    name = "xwayland-empty-floating-no-focus",
                    match = {
                        class = "^$",
                        title = "^$",
                        xwayland = true,
                        float = true,
                        fullscreen = false,
                        pin = false,
                    },
                    no_focus = true,
                })

                -- Satty
                hl.window_rule({
                    name = "satty",
                    match = { class = "^com.gabm.satty$" },
                    float = true,
                    dim_around = true,
                    min_size = { 700, 500 },
                    center = true,
                })

                -- rmpc
                hl.window_rule({
                    name = "rmpc",
                    match = { class = "^rmpc$" },
                    float = true,
                    size = { "monitor_w*0.6", "monitor_h*0.5" },
                    center = true,
                })

                -- cava
                hl.window_rule({
                    name = "cava",
                    match = { class = "^cava$" },
                    float = true,
                    size = { "monitor_w*0.3", "monitor_h*0.2" },
                    center = true,
                })

                -- yazi
                hl.window_rule({
                    name = "yazi",
                    match = { class = "^yazi$" },
                    float = true,
                    size = { "monitor_w*0.8", "monitor_h*0.8" },
                    center = true,
                })

                -- Layer rules
                hl.layer_rule({
                    name = "blur-rofi",
                    match = { namespace = "^rofi$" },
                    blur = true,
                })
            '';
        };
    };
}
