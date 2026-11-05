# README.md

```markdown
# dotfiles

Declarative NixOS + Home Manager configuration for **x1extreme**.
Single flake, one host, everything driven by feature toggles.

---

## Architecture

The whole configuration is built around **two option namespaces** and
**one rule**: no module does anything unless a flag in `hostSettings.*`
or `userSettings.*` turns it on.

```nix
lib.mkIf config.hostSettings.<feature>.enable { ... }   # system side
lib.mkIf config.userSettings.<feature>.enable { ... }   # home side
```

Host files (`hosts/x1extreme/*.nix`) contain nothing but those flags.
`modules/**/*.nix` contain nothing but the implementations. Adding or
disabling a subsystem is a one-line change in `configuration.nix` or
`home-<user>.nix` — never a comment-out-the-import dance.

### Two layers

| Namespace        | Level        | Consumed by                |
|------------------|--------------|----------------------------|
| `hostSettings`   | NixOS        | `modules/system/**`        |
| `userSettings`   | Home Manager | `modules/user/**`          |

`hosts/x1extreme/configuration.nix` reads like a manifest:

```nix
hostSettings = {
  audio.enable                    = true;
  gaming.enable                   = true;
  sddm.enable                     = true;
  security.sudo-rs.enable         = true;
  hardware.graphics.nvidia.enable = true;
  hardware.laptop.enable          = true;
  desktop.hyprland.enable         = true;
  virtualization.docker.enable    = true;
  virtualization.libvirt.enable   = true;
  styling = { enable = true; theme = "blood-moon"; };
};
```

`hosts/x1extreme/home-atiumtea.nix` does the same for the user side.
Some `userSettings` derive themselves automatically — e.g.
`userSettings.shells.zsh.enable` is forced on if `osConfig` has zsh as
the login shell, and `userSettings.browsers.<x>.enable` follows
`browsers.defaultBrowser`.

### User → Home Manager wiring

`hosts/x1extreme/default.nix` reads `hostSettings.users` (a list of
`{ name, isAdmin, shell? }`) and generates, for each user:

- a `users.users.<name>` entry with the right groups
  (`wheel`, `docker`, `libvirtd`, `gamemode`, `dialout` — from other
  `hostSettings.*` flags);
- a `home-manager.users.<name>` block that imports
  `home-<name>.nix` + `modules/user`, and passes the username down as
  `_module.args.username` (needed by `modules/user/shells`).

Adding a second user is one entry in `hostSettings.users` plus a
`home-<name>.nix`.

### Themes

`modules/themes/<name>/default.nix` is a base16 attrset:

```nix
{ scheme = "DUNE"; polarity = "dark";
  background = ./wallpaper.jpg;
  base00 = "16120e"; base05 = "ffae57"; /* … */ }
```

`hostSettings.styling.theme` selects one. Both `modules/system/styling/stylix.nix`
and `modules/user/styling/stylix.nix` import the same file and hand it to
Stylix. SDDM, GRUB, Plymouth, rofi, kitty, Hyprland, cava and rmpc all
read colors from `config.lib.stylix.colors` — swapping one string
recolors the entire system.

Custom GRUB / Plymouth themes live in
`modules/system/styling/{grub,plymouth}/themes/<name>/theme.nix` and are
picked with `styling.grub.theme` / `styling.plymouth.theme`. `"stylix"`
(a flat color) is always a valid value.

`lib/default.nix` exposes `collectDirs`, used to auto-discover theme
directories so the option `enum` never drifts.

### Structure

```
flake.nix
lib/                             # collectDirs and tiny helpers
hosts/
  x1extreme/
    default.nix                  # wires hostSettings.users → home-manager
    configuration.nix            # hostSettings flags
    hardware-configuration*.nix  # generated + manual kernel params
    home-atiumtea.nix            # userSettings flags
modules/
  system/                        # NixOS modules (hostSettings.*)
    configuration.nix            # base system: nix-daemon, nh, GRUB, locales, chrony
    users.nix                    # creates users from hostSettings.users
    audio.nix  gaming.nix  virtualization.nix  security/
    desktop/{hyprland,niri}.nix
    hardware/{bluetooth,laptop}.nix  hardware/graphics/{amd,nvidia,virtio}.nix
    kernel/                      # opt-in CachyOS kernel + tty0tty module
    postgresql/                  # opt-in Postgres
    sddm/                        # SDDM Astronaut wired to Stylix colors
    styling/                     # stylix.nix, fonts.nix, grub/, plymouth/
  user/                          # Home Manager modules (userSettings.*)
    home.nix  git.nix  security.nix  xdg.nix
    shells/   terminals/  browsers/  editors/  misc/
    desktop/
      common/                    # rofi, waybar, mako, yazi, grimblast, satty
      hyprland/                  # hyprland, hypridle, hyprlock, hyprsunset, hyprpaper
      niri/
    styling/                     # cursors, fonts, stylix (HM side)
  themes/
    dune/                        # base16 scheme + wallpaper
scripts/
  apply-boot.sh                  # rebuild wrapper (see below)
```

---

## What's in the modules

**System (`modules/system/`)**

| File                     | Provides                                                       |
|--------------------------|----------------------------------------------------------------|
| `configuration.nix`      | nix-daemon limits, `nh`, GRUB, EFI, locales, chrony, fstrim    |
| `users.nix`              | user accounts + groups from `hostSettings.users`               |
| `audio.nix`              | PipeWire + WirePlumber + JACK + rtkit + `playerctld`, pavucontrol |
| `gaming.nix`             | Steam, Gamemode, `proton-ge-bin`                               |
| `virtualization.nix`     | libvirt/QEMU/KVM (+virtiofsd, SPICE USB redirection), Docker   |
| `security/`              | `sudo-rs`, restricted to `wheel`                               |
| `desktop/hyprland.nix`   | `programs.hyprland`                                            |
| `desktop/niri.nix`       | `programs.niri`                                                |
| `hardware/bluetooth.nix` | BlueZ + blueman                                                |
| `hardware/laptop.nix`    | NVIDIA Prime offload, finegrained power management, brightnessctl |
| `hardware/graphics/`     | `hardware.graphics` + nvidia (open, modesetting, vaapi), amd, virtio |
| `kernel/`                | optional CachyOS kernel (`cachyosKernels.*`, scx_lavld), tty0tty |
| `postgresql/`            | optional local Postgres with declarative users/dbs             |
| `sddm/`                  | SDDM Astronaut, colors fed from Stylix                         |
| `styling/`               | Stylix (polarity, image, fonts), fontconfig, GRUB/Plymouth themes |

**Home (`modules/user/`)**

| File                          | Provides                                                |
|-------------------------------|---------------------------------------------------------|
| `shells/zsh.nix`              | zsh + autosuggestions + syntax-highlighting + fzf-tab   |
| `shells/default.nix`          | starship, fzf, zoxide, eza, bat, direnv, tmux, fastfetch |
| `terminals/kitty.nix`         | kitty (opacity, ligatures, no bell)                     |
| `browsers/firefox.nix`        | Firefox, arkenfox `user.js`, uBlock/Privacy Badger, DoH |
| `browsers/zen.nix`            | Zen browser                                             |
| `editors/nixvim/`             | NixVim: blink-cmp, LSP (nixd, clangd, rust-analyzer, ruff, ty, yamlls, helm_ls, terraformls), telescope, treesitter, oil, gitsigns, lazygit, trouble, conform, which-key, todo-comments, bufferline, lualine, typst-preview |
| `editors/vscode.nix`          | VS Code                                                 |
| `desktop/common/`             | rofi, waybar, mako, yazi, grimblast, satty, wl-clipboard, linux-wallpaperengine |
| `desktop/hyprland/`           | Hyprland, hypridle, hyprlock, hyprsunset, hyprpaper, XDG portals |
| `desktop/niri/`               | Niri + grimblast/satty                                  |
| `misc/`                       | discord, mpv, btop, feh, lazydocker, mpd + rmpc + cava, obsidian |
| `styling/`                    | cursors (Quintom), fonts, Stylix HM targets             |
| `git.nix`                     | git + lazygit (overrideGpg)                             |
| `security.nix`                | gpg, ssh, ssh-agent, gpg-agent (pinentry-qt)            |
| `xdg.nix`                     | XDG dirs, mimeApps                                      |

---

## Custom scripts

**`scripts/apply-boot.sh`** — safe rebuild wrapper around `nh os`.
Subcommands: `check`, `build`, `diff` (uses `nvd`), `switch`, `boot`,
`test`, `update` (reverts `flake.lock` if the build fails), `info`.
On successful `switch`/`boot` it creates a `gen-<N>` git tag.
Refuses to build on a dirty tree unless `--force`.

**`modules/user/desktop/common/waybar-bluetooth-display.sh`** — tiny
helper that renders the current Bluetooth connection in waybar.

**`modules/user/desktop/common/rofi/powermenu.sh`** — the rofi
power menu.

---

## Aliases

```sh
ls  = eza --color=always
cat = bat
..  = cd ..
```

Plus starship/fzf/zoxide integration from their respective HM modules.

---

## Hotkeys

### Hyprland (`$mainMod = SUPER`)

| Key                         | Action                                |
|-----------------------------|---------------------------------------|
| `SUPER+Q`                   | terminal                              |
| `SUPER+C`                   | kill window                           |
| `SUPER+M`                   | exit Hyprland                         |
| `SUPER+E`                   | file manager (yazi)                   |
| `SUPER+F`                   | toggle floating                       |
| `SUPER+R`                   | rofi launcher                         |
| `SUPER+1..0`                | workspace 1..10                       |
| `SUPER+SHIFT+1..0`          | move window to workspace              |
| `SUPER+S`                   | special workspace                     |
| `SUPER+SHIFT+S`             | move window to special                |
| `SUPER+J/K`                 | move window left/right                |
| `SUPER+SHIFT+J/K`           | move window down/up                   |
| `SUPER+KP_ENTER`            | rofi power menu                       |
| `SUPER+L`                   | hyprlock                              |
| `SUPER+F5`                  | toggle keyboard backlight (`kbtoggle`) |
| `SUPER+N` / `SUPER+SHIFT+N` | rmpc / cava                           |
| `PRINT`                     | grimblast area → clipboard            |
| `SUPER+PRINT`               | grimblast area → file                 |
| `SHIFT+PRINT`               | grimblast area → satty edit           |
| `ALT+PRINT`                 | grimblast full screen → clipboard     |
| `SUPER+ALT+PRINT`           | grimblast full screen → file          |
| `SUPER+drag` / right-drag   | move / resize window                  |
| `XF86Audio*`, `XF86MonBrightness*` | volume / mute / brightness     |

Waybar, hyprlock, hypridle and hyprsunset are all configured from the
same Stylix palette.

### NixVim (`leader = Space`)

| Key           | Action                                  |
|---------------|-----------------------------------------|
| `<Esc>`       | clear search highlight                  |
| `<C-o>`       | open Oil                                |
| `s` / `ss` / `S` | substitute (operator / line / EOL)   |
| `s` (visual)  | substitute selection                    |
| `gR` / `gd` / `gD` / `gt` | references / definitions / declaration / type definitions |
| `K`           | hover                                   |
| `ca`          | code action                             |
| `<leader>rn`  | rename                                  |
| `<leader>d`   | diagnostic float                        |
| `<leader>]d` / `<leader>[d` | next / prev diagnostic     |
| `<leader>ff` / `<leader>fs` | telescope files / live grep |
| `<leader>lg`  | lazygit                                 |
| `<leader>sv` / `sh` / `se` / `sx` | split v / split h / equalize / close |
| `<leader>to` / `tp` / `tn` / `tx` | new / prev / next / close tab |
| `<leader>xw` / `xd` / `xq` / `xl` / `xt` | trouble workspaces / buffer / quickfix / loclist / todo |
| `]h` / `[h`   | next / prev hunk                        |

---

## Adding a host

`flake.nix` builds `nixosConfigurations` from a plain list:

```nix
hosts = [ "x1extreme" ];
```

To add a host, drop a `hosts/<name>/` with `default.nix`,
`configuration.nix`, `hardware-configuration.nix` and
`home-<user>.nix`, then append the name to that list. Everything else
is shared through `modules/`.
```