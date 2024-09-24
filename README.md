# _Yomi (黄泉)_

based on [everything-nix](https://github.com/prescientmoon/everything-nix)

In case you are not familiar with nix/nixos, this is a collection of configuration files which build all my systems in a declarative manner. The tool used to configure the global system is called [nixos](https://nixos.org/), and the one used to configure the individual users is called [home-manager](https://github.com/nix-community/home-manager).

> A [visual history](./docs/history.md) of my setup is in the works!

## Features this repository includes:

- Sets up all the apps I use — including git, neovim, fish, tmux, starship, hyprland, anyrun, discord, zathura, foot & much more.
- Sets up my entire homelab — including zfs-based [impermanence](https://grahamc.com/blog/erase-your-darlings), automatic let's-encrypt certificates, tailscale, syncthing, vaultwarden, whoogle, pounce, calico, smos, intray, actual & more.
- Consistent base16 theming using [stylix](https://github.com/danth/stylix)
- Declarative secret management using [sops-nix](https://github.com/Mic92/sops-nix)

## Hosts

This repo's structure is based on the concept of hosts - individual machines configured by me. I'm naming each host based on things in space/mythology (_they are the same picture_). The hosts I have right now are:

- [amaterasu](./hosts/nixos/amaterasu/) — my personal laptop
- [tsukuyomi](./hosts/nixos/tsukuyomi/) — my tower pc
- susanoo — my android phone. Although not configured using nix, this name gets referenced in some places

## File structure

| Location                     | Description                                         |
| ---------------------------- | --------------------------------------------------- |
| [common](./common)           | Configuration loaded on both nixos and home-manager |
| [devshells](./devshells)     | Nix shells                                          |
| [docs](./docs)               | Additional documentation regarding my setup         |
| [home](./home)               | Home manager configurations                         |
| [hosts/nixos](./hosts/nixos) | Nixos configurations                                |
| [modules](./modules)         | Custom generic/nixos/home-manager modules           |
| [overlays](./overlays)       | Nix overlays                                        |
| [pkgs](./pkgs)               | Nix packages                                        |
| [flake.nix](./flake.nix)     | Nix flake entrypoint!                               |
| [scripts](./scripts)         | Bash scripts that come in handy when on a live cd   |
| [.sops.yaml](./.sops.yaml)   | Sops entrypoint                                     |
| [stylua.toml](./stylua.toml) | Lua formatter config for the repo                   |

## Points of interest

Here's some things you might want to check out:

- My [neovim config](./home/features/neovim/default.nix)
  - written using [nixvim](https://nix-community.github.io/nixvim)
- The [flake](./flake.nix) entrypoint for this repository

## Things I use

> This does not include links to every plugin I use for every program here. You can see more details in the respective configurations.

### Fundamentals

- [Nixos](http://nixos.org/) — nix based operating system
- [Home-manager](https://github.com/nix-community/home-manager) — manage user configuration using nix
- [Impernanence](https://github.com/nix-community/impermanence) — see the article about [erasing your darlings](https://grahamc.com/blog/erase-your-darlings)
- [Sops-nix](https://github.com/Mic92/sops-nix) — secret management
- [disko](https://github.com/nix-community/disko) — format disks using nix
  - [zfs](https://openzfs.org/wiki/Main_Page) — filesystem

### Graphical

- [Stylix](https://github.com/danth/stylix) — base16 module for nix
  - [Base16 templates](https://github.com/chriskempson/base16-templates-source) — list of base16 theme templates
  - [Catpuccin](https://github.com/catppuccin/catppuccin) — base16 theme I use
  - [Rosepine](https://rosepinetheme.com/) — another theme I use
- [Hyprland](https://hyprland.org/) — wayland compositor
  - [Wlogout](https://github.com/ArtsyMacaw/wlogout) — wayland logout menu
  - [Hyprpicker](https://github.com/hyprwm/hyprpicker) — hyprland color picker
  - [Grimblast](https://github.com/hyprwm/contrib/tree/main/grimblast) — screenshot tool
  - [Dunst](https://dunst-project.org/) — notification daemon
  - [Wlsunset](https://sr.ht/~kennylevinsen/wlsunset/) — day/night screen gamma adjustments
  - [Anyrun](https://github.com/Kirottu/anyrun) — program launcher
- [Foot](https://codeberg.org/dnkl/foot) — terminal emulator
- [Zathura](https://pwmt.org/projects/zathura/) — pdf viewer
- [Firefox](https://www.mozilla.org/en-US/firefox/) — web browser
- [Tesseract](https://github.com/tesseract-ocr/tesseract) — OCR engine
- [Obsidian](https://obsidian.md/) — note taking software
- [Bitwarden](https://bitwarden.com/) — client for self-hosted password manager

### Terminal

> There are many clis I use which I did not include here, for the sake of brevity.

- [Neovim](https://neovim.io/) — my editor
  - [Neovide](https://neovide.dev/index.html) — neovim gui client
  - [Vimclip](https://github.com/hrantzsch/vimclip) — vim anywhere!
- [Tmux](https://github.com/tmux/tmux/wiki) — terminal multiplexer
- [Fish](https://fishshell.com/) — user friendly shell
  - [Starship](https://starship.rs/) — shell prompt
- [yazi](https://github.com/sxyazi/yazi) — file manager
- [lazygit](https://github.com/jesseduffield/lazygit) — git tui

### Services

> In the future when I have my synology nas

Most services are served over [tailscale](https://tailscale.com/), using certificates generated by [let's encrypt](https://letsencrypt.org/).

- [Actual](https://actualbudget.org/) — budgeting tool.
- [Commafeed](https://github.com/Athou/commafeed) — rss reader
- [Forgejo](https://forgejo.org/) — git forge
- [Grafana](https://github.com/grafana/grafana) — pretty dashboards
- [Guacamole](https://guacamole.apache.org/) — remote desktop access
- [Homer](https://github.com/bastienwirtz/homer) — server homepage
- [Intray](https://github.com/NorfairKing/intray) — GTD capture tool.
- [Invidious](https://invidious.io/) — alternate youtube client
- [Jellyfin](https://jellyfin.org/) — media server
- [Jupyterhub](https://jupyter.org/hub) — notebook collaboration suite
- [Microbin](https://microbin.eu/) - code & file sharing service
- [Pounce](https://git.causal.agency/pounce/about/) & [calico](https://git.causal.agency/pounce/about/calico.1) — irc bouncer
- [Prometheus](https://github.com/prometheus/prometheus) — metric collector
- [Qbittorrent](https://www.qbittorrent.org) — torrent client
- [Radicale](https://radicale.org/v3.html) — calendar server
- [Redlib](https://github.com/redlib-org/redlib) — alternate reddit client
- [Smos](https://github.com/NorfairKing/smos) — a comprehensive self-management system.
- [Syncthing](https://syncthing.net/) — file synchronization
- [Vaultwarden](https://github.com/dani-garcia/vaultwarden/) — password manager
- [Whoogle](https://github.com/benbusby/whoogle-search#manual-docker) — search engine
  OR SearXNG
- [Calibre Web]() - A online libary for my books
- [Plex]() - A hosting service for music, movies, etc. similar to [Jellyfin]()

## Hall of fame

Includes links to stuff which used to be in the previous section but is not used anymore.

- [Kitty]() — I switched to [Foot](https://codeberg.org/dnkl/foot)
- [Eww](https://github.com/elkowar/eww) - experimented with eww for a bit, but setup was painful and bars are a bit useless
