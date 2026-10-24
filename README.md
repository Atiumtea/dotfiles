# NixOS Config — `x1extreme`

Flake-based NixOS configuration for a Lenovo ThinkPad X1 Extreme Gen 2.  
Built around **feature flags** so each module can be enabled or disabled per host without touching the rest of the tree.

---

## Features

- **Flake-based**, pinned via `flake.lock`
- **Home Manager** integration via the NixOS module
- **Declarative per-host feature toggles** — `hostSettings.*` for system, `userSettings.*` for the user
- **Unified theming** with Stylix + base16 (currently: `signalis`, with `dune` in the wings)
- **Wayland desktop** — Hyprland (default) or Niri
- **Editors** — NixVim (blink-cmp, telescope, treesitter, oil, gitsigns, dadbod, …), VS Code, IntelliJ IDEA
- **Browsers** — Firefox (arkenfox-hardened) and Zen Browser, selectable default
- **Terminal stack** — kitty, zsh + starship, tmux, fzf/fd/ripgrep/bat/eza, zoxide, direnv
- **Gaming** — Steam, GameMode, Proton-GE; Bottles via declarative Flatpak
- **Virtualization** — Docker and/or libvirt/QEMU (optional)
- **VPN** — Mullvad (system daemon + user tray)
- **Networking** — NetworkManager, chrony, optional Blocky DNS for Firefox DoH
- **Hardware helpers** — NVIDIA PRIME offload, Bluetooth, backlight, CachyOS kernel (opt-in)
- **Custom system modules** — PostgreSQL bootstrap, Iriun webcam, `tty0tty`, custom GRUB / Plymouth themes (`cybergrub-2077`, `arasaka`)
- **Nice boot/login** — SDDM Astronaut theme, Plymouth, themed GRUB
- **Ops scripts** — `scripts/apply-boot.sh` (rebuild helper) and `scripts/snapshot-config.sh` (config snapshot generator)

---

## Structure

```
.
├── flake.nix                     # entry point, host list, overlays, inputs
├── alejandra.toml                # formatter config (4 spaces)
├── lib/                          # small helpers (e.g. collectDirs)
│
├── hosts/
│   └── x1extreme/
│       ├── default.nix           # wires host + user modules together
│       ├── configuration.nix     # hostSettings: what this machine runs
│       ├── hardware-configuration.nix
│       ├── hardware-configuration-additional.nix
│       └── home-atiumtea.nix     # userSettings: what this user runs
│
├── modules/
│   ├── system/                   # system-level NixOS modules
│   │   ├── configuration.nix     # nix daemon, locale, tz, bootloader, …
│   │   ├── audio.nix
│   │   ├── gaming.nix
│   │   ├── mullvad.nix
│   │   ├── users.nix
│   │   ├── virtualization.nix
│   │   ├── desktop/              # hyprland / niri
│   │   ├── hardware/             # graphics (nvidia / amd / virtio), bluetooth, laptop
│   │   ├── iriun/                # webcam-over-phone module
│   │   ├── kernel/               # cachyos kernel + tty0tty
│   │   ├── postgresql/
│   │   ├── sddm/
│   │   ├── security/             # sudo-rs
│   │   └── styling/              # stylix, fonts, grub & plymouth themes
│   │
│   ├── user/                     # Home Manager modules
│   │   ├── home.nix
│   │   ├── git.nix
│   │   ├── mullvad.nix
│   │   ├── security.nix
│   │   ├── xdg.nix
│   │   ├── browsers/
│   │   ├── desktop/              # hyprland, niri, waybar, rofi, mako
│   │   ├── editors/              # nixvim, vscode, idea
│   │   ├── misc/                 # music, obsidian, btop, lazydocker, …
│   │   ├── shells/               # zsh + starship + tmux
│   │   ├── styling/              # cursors, fonts, stylix
│   │   └── terminals/            # kitty
│   │
│   └── themes/                   # base16 schemes (dune, …)
│
└── scripts/
    ├── apply-boot.sh             # nh-based rebuild helper
    └── snapshot-config.sh        # dumps the repo as a single text file
```

---

## How it works

Each host is a **list of features** — nothing more.

```nix
# hosts/x1extreme/configuration.nix
hostSettings = {
  users = [{ name = "atiumtea"; isAdmin = true; }];

  audio.enable              = true;
  gaming.enable             = true;
  mullvad.enable            = true;
  virtualization.docker.enable  = true;
  virtualization.libvirt.enable = true;
  desktop.hyprland.enable   = true;
  sddm.enable               = true;

  hardware.graphics.nvidia.enable = true;
  hardware.laptop.enable    = true;

  styling = {
    enable = true;
    theme  = "signalis";
    fonts.serif = { name = "Fira Sans"; package = pkgs.fira-sans; };
    plymouth.enable = true;
    plymouth.theme  = "arasaka";
    grub.theme      = "cybergrub-2077";
  };
};
```

Each module in `modules/system/` and `modules/user/` follows the same pattern:

```nix
options.hostSettings.gaming.enable = lib.mkEnableOption "gaming support";

config = lib.mkIf config.hostSettings.gaming.enable {
  programs.steam.enable = true;
  programs.gamemode.enable = true;
};
```

So the answer to *"what does this machine do?"* is always one file: `hosts/<host>/configuration.nix` (for the system) and `hosts/<host>/home-<user>.nix` (for the user).

---

## Usage

Requires Nix with flakes enabled.

```bash
# build only
nix build .#nixosConfigurations.x1extreme.config.system.build.toplevel

# apply immediately
sudo nixos-rebuild switch --flake .#x1extreme

# apply to next boot
sudo nixos-rebuild boot --flake .#x1extreme

# run the helper script (wraps nh, adds checks + logging)
./scripts/apply-boot.sh switch
./scripts/apply-boot.sh diff      # show what would change, no apply
./scripts/apply-boot.sh update    # nix flake update && switch
./scripts/apply-boot.sh check     # alejandra + flake check only
```

The helper writes logs to `~/snapshots/rebuild-<host>-<ts>.log` and refuses to run as root.

---

## Adding a new host

1. Create `hosts/<newname>/` with `configuration.nix`, `home-<user>.nix`, and hardware files.
2. Add `"<newname>"` to the `hosts` list in `flake.nix`.
3. Flip the `hostSettings.*` / `userSettings.*` flags you want.

That's it — everything else is shared.

---

## Design notes

- **No `imports` soup.** Modules don't import each other; they read `config.hostSettings.*`. One import list lives in `modules/system/default.nix` and `modules/user/default.nix`.
- **Common + host-specific split.** Everything reusable lives under `modules/`; the host directory only carries hardware quirks and feature flags.
- **Fully declarative Flatpak.** Bottles is installed via `nix-flatpak` with a scoped filesystem permission (`~/Games/Isaac:rw`), not `flatpak install`.
- **`lib.collectDirs`** scans `modules/themes`, GRUB themes, and Plymouth themes — drop a directory in and it's automatically selectable.
- **`sops-nix` is prepared but not wired.** Secrets are on the TODO (`OPENROUTER_API_KEY` placeholder in `home-atiumtea.nix`).
- **Snapshot script** — `scripts/snapshot-config.sh` produces a single-file view of the repo (like the one this README was written against), useful for sharing or archiving configs.

---

## Compatibility

- NixOS `26.05` (system) / Home Manager `25.05`
- Tested on: **x86_64-linux**, Lenovo ThinkPad X1 Extreme Gen 2
- Uses `nixos-hardware` for the ThinkPad module and `inputs.niri` / `inputs.nixvim` / `inputs.stylix` / `inputs.nix-flatpak` (see `flake.lock`)

---

## License

Personal configuration — no license provided. Borrow whatever is useful.