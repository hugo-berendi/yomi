# Home

The pilot's Home Manager configuration: what they use on their machines,
from the shell and CLI tools to Neovim, the Wayland session, desktop
applications, mail and calendar. Per-host settings live beside each host in
`hosts/nixos/<host>/home.nix`.

**One rule decides which side a file is on: a file named `system.nix` is a
NixOS module; every other `.nix` file is a Home Manager module.** A feature
with both halves keeps them together, e.g. `features/wayland/hyprland/default.nix`
(Home Manager) beside `features/wayland/hyprland/system.nix` (NixOS).

| Path | Holds |
|---|---|
| `default.nix` | the base every host with a user environment gets: flake modules, CLI, Neovim, persistence, shared theming |
| `wsl.nix` | what the WSL hosts add |
| `features/cli/` | shell, git, ssh/gpg, tmux, yazi, the AI tooling in `cli/ai/` |
| `features/neovim/` | nvf configuration |
| `features/wayland/` | Hyprland and the session around it (waybar, notifications, lock, idle) |
| `features/desktop/` | GUI applications; `desktop/system.nix` is the NixOS side of the desktop |
| `features/productivity/` | mail and calendar |
| `features/persistence.nix` | where the pilot's persisted state, cache and data live |

## How a host gets a feature

- `profiles/home-manager.nix` gives the pilot Home Manager with
  `home/default.nix`. The desktop, server and WSL profiles import it.
- `profiles/desktop.nix` adds `home/features/desktop/system.nix` on the NixOS
  side and `home/features/wayland/hyprland` on the Home Manager side;
  Hyprland brings `features/wayland/global.nix`, which brings
  `features/desktop/`.
- `profiles/wsl.nix` adds `home/wsl.nix`.
- A host adds anything else in its `hosts/nixos/<host>/home.nix`.
- The system halves of fish and 1Password are imported by `profiles/base.nix`
  and `profiles/fleet.nix`.

## Conventions

- Persist application state with
  `yomi.persistence.at.{state,cache}.apps.<name>.directories`; set
  `excludeFromLocalBackups = true` for large data that needs no backup.
- Lua for Neovim: tabs, width 4, at most 120 columns (`stylua.toml`). Plugins
  are configured through `programs.nvf.settings.vim`.
- ghostty is configured through `programs.ghostty`, with the module's bash,
  fish and systemd extras switched off to keep the previous output.
- A successful evaluation does not mean the program accepts the file. Check
  generated configuration with its consumer: the greeter's desktop entries,
  wlogout's object-stream format, the installed zathura options, Hyprland's
  active bindings and window identities, and Neovim's state path under
  `NVIM_APPNAME`.
