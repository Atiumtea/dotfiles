# dotfiles

Personal NixOS configuration — ThinkPad X1 Extreme Gen 2.
Dark, modular, and built to evolve.

## Quick start

```bash
git clone git@github.com:Atiumtea/dotfiles ~/dotfiles
cd ~/dotfiles && direnv allow
nixapply switch
```

## Rebuild

```bash
nixapply switch          # Apply now
nixapply boot            # Apply to next boot
nixapply check           # Format + flake check
nixapply update          # Update inputs, then switch
nixsnap --full           # Save full config snapshot
```

Manual fallback:

```bash
sudo nixos-rebuild switch --flake ~/dotfiles#x1extreme --max-jobs 1 --cores 2
```

## Publishing to GitHub

1. Create a **new empty repo** on GitHub (do not fork — this diverged from the
   template).
2. Add it as remote and push:

```bash
git remote add origin git@github.com:Atiumtea/dotfiles.git
git branch -M main
git add -A
git commit -m "Initial commit"
git push -u origin main
```

## Structure

```
hosts/x1extreme/           # Your machine — hostSettings + userSettings
modules/system/            # Host-wide modules (audio, gaming, hardware, styling)
modules/user/              # Per-user modules (shells, desktop, editors, browsers)
modules/themes/            # Base16 theme definitions
scripts/                   # apply-boot.sh, snapshot-config.sh
```

Every feature is gated behind a boolean. See the how-to guide below.

## Themes

Available: `blood-moon`, `dune`, `cyberpunk`, `catppuccin-mocha`, `nord`,
`rose-pine`, `tokyo-night`.

Switch in `hosts/x1extreme/configuration.nix`:

```nix
styling.theme = "blood-moon";
```

## Keybinds

| Key | Action |
|-----|--------|
| `Super + Q` | Terminal |
| `Super + R` | App launcher |
| `Super + E` | File manager |
| `Super + F` | Toggle float |
| `Super + 1-0` | Switch workspace |
| `Super + S` | Scratchpad |
| `Super + L` | Lock |
| `Super + F5` | Keyboard backlight |
| `Fn + Space` | KB backlight up/down |
| `Print` | Screenshot area |
| `Shift + Print` | Screenshot + edit |

## Steam / Gaming

Gaming is enabled via `hostSettings.gaming.enable = true`. To install any game
(including Wallpaper Engine):

1. Launch Steam (`Super + R` -> Steam).
2. Install through Steam's store/library normally.
3. Wallpaper Engine: after installing in Steam, use `linux-wallpaperengine`
   (already installed) as the renderer.

## OLED protection

Hyprland doesn't have built-in pixel shift. What you have:

- **Dark themes**: `blood-moon` uses near-black background.
- **Auto-lock**: 10 min idle triggers `hyprlock`.
- **Sunset dimming**: `hyprsunset` warms colors at night.
- Reduce idle lock timeout in `modules/user/desktop/hyprland/hypridle.nix`
  if you want faster lock.

## Shell aliases

```
ls   -> eza --color=always
cat  -> bat
..   -> cd ..
```

---

## How-to guide

### Add a package

System-wide -> `modules/system/configuration.nix` (`environment.systemPackages`).
User -> `modules/user/misc/default.nix` (`home.packages`).

[search.nixos.org](https://search.nixos.org/packages)

### Add a browser

Create `modules/user/browsers/<name>.nix` (copy `firefox.nix`), then:

```nix
userSettings.browsers.defaultBrowser = "<name>";
```

Browsers auto-discover. **2 files touched.**

### Add a Neovim plugin

Search [nixv.im](https://nixv.im), add to `modules/user/editors/nixvim/plugins/misc.nix`. **1 file.**

### Add a VS Code extension

Search `vscode-extensions` on search.nixos.org, add to `modules/user/editors/vscode.nix`. **1 file.**

### Add a Hyprland keybind

In `modules/user/desktop/hyprland/hyprland.nix`, add to `bind = [`:

```nix
"$mainMod, B, exec, brave"
```

**1 file.**

### Add a shell alias

Add to `home.shellAliases` in `modules/user/shells/default.nix`. **1 file.**

### Add a script

Create `scripts/my-tool.sh`, wrap in `modules/user/scripts/default.nix`. **2 files.**

### Add a theme

Create `modules/themes/<name>/` with `default.nix` (16 base16 hex colors) and a
wallpaper. Set `styling.theme = "<name>"` in your config. **2 files.**

Pre-made palettes: [base16-schemes](https://github.com/tinted-theming/base16-schemes).

### Add a feature with its own toggle

Create `modules/user/<category>/<feature>.nix`:

```nix
{
    options = { userSettings.feature.enable = lib.mkEnableOption "..."; };
    config = lib.mkIf config.userSettings.feature.enable { /* ... */ };
}
```

Import in parent `default.nix`, enable in your home file. **3 files.**

### How components connect

```
configuration.nix  ->  hostSettings.*  ->  modules/system/  ->  NixOS config
home-*.nix         ->  userSettings.*  ->  modules/user/    ->  Home Manager config
```

Rule: module declares an option, your host file flips the switch.

## Formatting

```bash
alejandra ~/dotfiles
```

4-space indent.

## License

Public domain ([UNLICENSE](UNLICENSE)).