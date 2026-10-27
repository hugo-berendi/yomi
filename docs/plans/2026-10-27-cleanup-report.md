# Project review and cleanup plan (2026-10-27)

Scope: the whole repository, read from `inari`. Nothing was changed except this file.

**How much to trust it.** Items marked ✔ I checked myself (grep or `nix eval`). The rest come from two read-only sweeps (inari services; home, common, modules, other hosts) that used grep and import-graph checks. Confirm each one with `nix eval` or a dry build before deleting. A file referenced only by a computed path (`flake.nix` builds `hosts/nixos/<name>` from strings) looks unused to grep.

## 1. Summary

| Area | Finding | Size of win |
|---|---|---|
| Dead files | About 25 unreferenced files, three disabled-forever services, a dead wireless backend, a dead Lua stack | High, low risk |
| Stray artefacts | `result` symlink, `log.txt`, tracked `.pyc`, symlinks into `~/.local/share` | Trivial |
| Custom vs official | 5 services where nixpkgs has a module; several hand-written configs where a `programs.*` module exists | Medium |
| Duplication | 28 inari files bypass `yomi.persistence`; llama-cpp is duplicated; `mkForce` boilerplate repeated | Medium |
| Structure | Three "common" trees, option definitions under `hosts/`, inconsistent `foo.nix` + `foo/` layout | High, needs care |
| tsukuyomi | Dormant host still in the eval graph | Decision needed |

## 2. Dead or unused (safe-ish deletions)

**Stray files, delete now**
- ✔ `result` (symlink to an ISO, gitignored) and `log.txt` (gitignored, 92 bytes of a failed rebuild).
- ✔ `hosts/nixos/inari/services/n8n/__pycache__/backfill.cpython-313.pyc` is tracked. Run `git rm` and add `__pycache__/` and `*.pyc` to `.gitignore`.
- `home/features/wayland/ags/types` and `ags/config/types` are tracked symlinks into `/home/hugob/.local/share/...`. They are machine-specific and no ags config exists.
- ✔ `TODO.md` holds two vague lines. Move them to an issue or delete the file.
- `hosts/nixos/inari/services/homepage.env.example` is referenced by nothing.

**Unreferenced Nix files** (✔ no reference by file name anywhere)
- `devshells/typescript.nix`, `dns/implementation/octodns-cloudflare.nix`, `home/features/cli/atuin.nix`, `home/tsukuyomi.nix`, `hosts/nixos/amaterasu/services/cgit.nix`, `modules/common/korora-neovim.nix` (277 lines), `modules/home-manager/discord.nix`.
- ✔ `dns/pkgs.nix` is dead and broken. It imports `modules/nixos/dns.nix` and `modules/common/octodns.nix`, and neither file exists. `flake.nix` uses `dns/implementation` only.
- `home/features/desktop/kitty/` (default.nix and the theme) is never imported. Foot and ghostty are the terminals in use.
- `home/features/desktop/dunst/dunstrc` (454 lines) is dead because swaync is the daemon. `scripts/backlight` and `scripts/volume` still point at a dunst icon path that no longer exists.
- Also unreferenced: `desktop/discord/template.mustache`, `wayland/waybar/diabetes.py`, `cli/yubikey.gpg`, `cli/scripts/shell.nix`, and in `cli/scripts/`: `chng-ip.sh`, `cht.sh`, `installupdates.sh`, `up-nix.sh`, `v`, `caway`, `excalidraw`, `weather.py`, `palette.py`.
- `modules/home-manager/firefox/`: nothing sets `programs.firefox.apps`.
- `common/icons/` (21 PNGs) is not referenced by any `.nix` file. About 10 wallpapers in `common/themes/` are unreferenced too (`cinnabar.png`, `crater.jpg`, `eye.png`, and others). Check them against the 10 `image =` entries in `common/themes/default.nix`.

**Unreferenced scripts and tests**
- ✔ `scripts/` files with no reference: `add2fa`, `age-public-key.sh` (the `just age-public-key` recipe replaces it), `komga-thumbnail-coverage.sh`, `lock.sh` (swaylock, but hyprlock is used), `pass-init.sh`, `rm_submodule.sh`, `secure-iso.sh`. Delete them or move them to a documented `scripts/oneoff/`.
- ✔ `tests/glooko-browser.py`, `tests/glooko-download.py` and `tests/n8n-diabetes.py` are not wired to any `.nix` or CI entry. Hook them into `checks` or delete them.
- `hosts/nixos/inari/services/n8n/backfill.py` (774 lines) is a one-off. The `just n8n-backfill` recipe keeps it alive, so retire both once the backfill is done.

**Dead options and modules**
- `yomi.toggles.*` (`modules/common/toggles.nix`) is set in four places and read nowhere.
- `yomi.themes` and `yomi.currentTheme` (`modules/common/themes.nix`) are never read or set.
- `yomi.dev.path` is unused.
- `yomi.restic.apps` is unused, and `yomi.restic.sets` is used only inside `restic.nix`.
- Neovide is disabled but costs about 60 lines in `neovim/default.nix`. It is the only consumer of `modules/common/{lua-lib,lua-colorscheme,korora-lua}.nix` and the `korora` flake input. Remove them as one unit.
- `hosts/nixos/common/wireless/`: only `networkmanager` is ever selected. `iwd/`, `wpa_supplicant.nix` and `networks.nix` are dead.
- Commented-out code to strip: `home/tsukuyomi.nix:17-20`, `home/features/productivity/default.nix:3-4`, `cli/fish/default.nix:62`, `adguard-home.nix:62-70`, and about 20 commented packages in `home/amaterasu.nix` and `home/tsukuyomi.nix`.

**Disabled-forever inari services** (each still carries secrets, vhosts or persistence)
- `media/recyclarr.nix` (`enable = false`).
- `redlib.nix` (the whole file is behind `enable = false`).
- `music/navidrome.nix`. It still registers a vhost and port while disabled.
- `services.jellarr` is disabled in `media/jellyfin.nix`, yet the `jellarr` flake input, the module import and an ungated sops secret remain.
- `guacamole` has `autoStart = false`. It is a container that never runs but still has a secret, persistence and a vhost.
- For each one, decide: enable it or delete it. A disabled service with live side effects is the worst state.

**Flake inputs.** ✔ I checked usage outside `flake.nix` for plain inputs. Every one I checked is referenced, except that `korora` goes away with neovide and `nixpkgs-unstable` is reached through `upkgs`. Inputs declared with `= { ... }` blocks (`mcp-nixos`, `hyprland`, `pyprland`, `nixarr`, `jellarr`, `nvf`, `nixcord`, `playit-nixos-module`, `flake-parts`) were not checked. Run `nix flake metadata` and grep for each.

**Temporary workarounds that became permanent** (document or revert)
- `zfs.nix:15-18` (`trim.enable = false`, "temporary" kernel panic note).
- `inari/default.nix:96-98` (`systemd.oomd` forced off "while diagnosing").
- `iso/default.nix:54-65` (`beelink-rescue` AMD SRSO specialisation).

## 3. Custom packaging that could use an official route

✔ Checked with `nix eval` against nixos-26.05 and unstable:

| Ours | Official? | Verdict |
|---|---|---|
| `pkgs/suwayomi-server.nix` 2.4.2366 | nixpkgs has `suwayomi-server` 2.1.1867 | Ours is newer. Keep, or move to `upkgs` when unstable catches up. |
| `pkgs/t3code-release.nix` 0.1.2 | unstable has `t3code` 0.1.0, stable 0.0.24 | Keep while ahead. Re-check weekly. |
| `pkgs/chatgpt.nix` 26.915 | nixpkgs `chatgpt` is a different package: 1.2026.048 on stable, 26.1016 on unstable | Check whether it is the same app. If so, drop ours. |
| `pkgs/cliproxyapi-copilot-plugin.nix` and the `cliproxyapi` `overrideAttrs` | `cliproxyapi` exists in unstable only | The override is acceptable. |
| `pelican-wings`, `helium`, `vimclip` | not in nixpkgs | Keep. Consider upstreaming. |
| `pkgs/chatgpt-launcher.nix` | no reference anywhere | ✔ Delete. |

**Services where nixpkgs has a module** (from the inari sweep, verified by option name only)
- `changedetection.nix` runs two pinned containers and a hand-made network. nixpkgs has `services.changedetection-io`. The browser sidecar is the only reason to keep a container.
- `guacamole/default.nix` uses the `flcontainers` image. nixpkgs has `services.guacamole-server` and `-client`. The service is off, so the swap is cheap.
- `protonmail-bridge.nix` is a custom unit. nixpkgs has `services.protonmail-bridge`. The gpg/pass keychain setup may justify the custom unit; if so, say so in a comment.
- `llama-cpp.nix` and `llama-cpp-classifier.nix` are hand-written units. `services.llama-cpp` exists. Weights are fetched by `curl` at start. A fixed-output fetch would be reproducible but puts roughly 22 GB in the store, so this is a trade-off, not a clear win.
- `media/flaresolverr.nix` is a pinned container. `pkgs.flaresolverr` exists, if nixarr does not provide one.
- `grafana.nix:69` fetches a dashboard with `fetchurl`. This is fine, but provisioning from a checked-in JSON file is more idiomatic.

**Home-manager: hand-written config where a module exists**
- `tealdeer.nix` → `programs.tealdeer`.
- `ghostty.nix` → `programs.ghostty`. Also drop the hard-coded theme, font and opacity in favour of `stylix.targets.ghostty`. (CLAUDE.md says ghostty has no home-manager module. Re-check, since that may be out of date on release-26.05.)
- `wlogout.nix` → `programs.wlogout` (has `layout` and `style` options).
- `hyprland/default.nix:368` writes `home.file.".config/hypr/pyprland.toml"`. Use `xdg.configFile`. The legacy-cleanup activation script at lines 355-365 can go.
- `common/avatar.nix:6` uses `builtins.fetchurl`, which fetches at evaluation time. Use `pkgs.fetchurl` with a hash.
- `cli/ai/opencode/package.nix` plus a 629-line `copilot-auto.patch` is a hand-built fork. `llm-agents` already provides `opencode`. Drop the fork when the upstream PR merges, or move it to `pkgs/`.

**Theming: one source of truth.** Stylix is imported, but many apps build their own palette from `config.lib.stylix.colors.baseXX`: `calibre.nix` (about 60 lines of colours), `zathura`, `spotify`, `karere`, `teams/`, the T3 Code theme JSON, and a second palette in `yomi.shellTheme`. Use `stylix.targets.*` where one exists and keep hand-built CSS only for apps without a target.

**Shell scripts.**
- About 14 inari files and several home files use `writeShellScript(Bin)`, which is not shellchecked and has no declared dependencies. Move them to real `.sh` files behind `writeShellApplication` (`runtimeInputs` plus shellcheck). `yomi-repo-sync.nix` is the local model. Targets: `radicale.nix:82-102`, `nextcloud.nix:40`, `changedetection.nix:10-17`, `n8n.nix:46`, `cliproxyapi.nix:109`, `protonmail-bridge.nix:24-37`, `restic-restore.nix:42`, `llama-cpp*.nix`, `wayland/global.nix:29-51`, `obsidian.nix:8`, `wlsunset.nix:8`.
- `cli/scripts/` ships `uptimes`, `volume` and `backlight` twice: through `writeShellScriptBin` and through a whole-directory symlink on `PATH`.

**Docker images.** Ten pins use `latest@sha256:…`. The tag is redundant next to a digest. Use the digest alone, as `sable.nix:64` does.

## 4. Duplication to fold into helpers

- 28 inari files write `environment.persistence."/persist/state".directories` directly. Only 6 use `yomi.persistence.at.state.apps.*`. `restic-app-state.nix:15-35` keeps its own hand-written list of state paths. Migrate the 28 files, then drive restic from `yomi.persistence.inventory`.
- `nextcloud.nix:63`, `calsync.nix:98` and `matrix/tuwunel.nix:152` define raw `services.nginx.virtualHosts` instead of `yomi.nginx.at`. `diabetes.nix:114` edits `locations."/"` directly.
- `DynamicUser = lib.mkForce false` appears 8 times (ntfy, miniflux, invidious, scrutiny ×2, tuwunel, gatus, forgejo). Add one helper, for example `yomi.service.persistentUser`. `PrivateNetwork`, `PrivateDevices` and `ProtectSystem` overrides repeat in five of those files.
- `docker network create` scripts repeat in `pelican/pelican.nix`, `pelican/wings.nix` and `changedetection.nix`. Add a `yomi.containers.networks.<name>` helper.
- `llama-cpp.nix` and `llama-cpp-classifier.nix` are about 220 lines of near-duplicate. Extract `mkLlamaServer`.
- Host package lists repeat in `home/{amaterasu,tsukuyomi,inari,wsl}.nix` (`nh`, `nix-output-monitor`, `nvd`, `sops`, `alejandra`, `pay-respects`, `sxiv`), as do `home.file = {}` and `EDITOR`. Move them into `home/features/cli`.
- `hosts/nixos/amaterasu/default.nix:11` and `tsukuyomi/default.nix:10` import `desktop/steam.nix`, which `desktop/default.nix` already imports.
- `wsl/default.nix` sets `wsl.defaultUser = "hugob"` while the same host sets `yomi.pilot.name`. Use the option.
- Sops secrets are not gated on `enable` for `jellarr` and `guacamole`, while `playit` gates its own.

## 5. Proposed structure

Today there are three "common" trees (`common/`, `modules/common/`, `hosts/nixos/common/`), and option declarations live in all of them.

**Rules**
1. `modules/{nixos,home-manager,common}` declare options and behaviour. Nothing under `hosts/` or `home/` calls `mkOption`.
2. `hosts/<host>/` holds only host-specific values and imports. `hosts/nixos/common/` becomes `modules/nixos/profiles/` (base, desktop, server), selected by `yomi.machine.*`.
3. `home/features/` holds user-level features. `common/` (themes, icons, fonts, avatar, caches) becomes `assets/` plus `modules/common/theming/`.
4. One layout rule for inari services: one directory per service with `default.nix`, or one `.nix` file. No `foo.nix` plus sibling `foo/`.
5. Documentation lives in `docs/`, not beside code.

**Concrete moves**
- Option declarations in `hosts/nixos/common/`: `base/flags.nix` (`yomi.machine`), `wireless/default.nix`, `filesystems/default.nix`, `services/tailscale.nix`. Move them to `modules/nixos/`.
- `yomi.ports`: the declaration is in `modules/nixos/ports.nix`, but the values live in `hosts/nixos/common/base/ports.nix`. Keep the values with the registry. Document it in `docs/custom-options.md`.
- `common/themes/default.nix` (299 lines, 10 themes): split into one file per theme plus `lib.nix`. Merge `modules/common/{theming,shell-theme,themes}.nix` into `modules/common/theming/`.
- `hosts/nixos/common/desktop/helium.nix:20` imports from `home/`. Move the extension list to a neutral place.
- inari layout:
  - `diabetes.nix` + `diabetes/`, `n8n.nix` + `n8n/`, `protonmail-bridge.nix` + `protonmail-bridge/`, `proton-mail-sorter.nix` + `proton-mail-sorter/`, `radicale.nix` + `radicale/`: become one directory each.
  - `restic.nix`, `restic-app-state.nix`, `restic-restore.nix` and `restic/` merge into `restic/`.
  - `music/` and `comics/` each hold one file. Flatten them or merge them into `media/`.
  - `services/proton-mail-sorter/secrets.yaml` is referenced from `protonmail-bridge.nix`. Move it up to match the other `../secrets.yaml` paths.
  - `services/n8n/AGENTS.md` (336 lines) moves to `docs/`, and the pointer in CLAUDE.md is updated.
  - Stub files: `matrix/element-web.nix` (3 lines), `fluffychat-web.nix` (6 lines).
  - `default.nix:11` imports an inline `{yomi.tailscale.enable = true;}` module. Move it to the options block.
- `scripts/` is a mix of install helpers, CI scripts and one-offs. Split into `scripts/ci/` (`update-package-pr.py`, `update-docker-digests.sh`), `scripts/ops/` (`hardening-report.*`, `inari-migration-check.sh`, `migrate-home-persistence.py`) and `scripts/desktop/` (`volume`, `backlight`, `wallpaper`, `live.sh`, `kagutsuchi.sh`).
- `devshells/`: ✔ `typescript` is not exported. Either add it to `devshells/default.nix` or delete it.
- `tests/` is flat, with Nix, Python and `.cjs` files side by side. Group by subject (`tests/n8n/`, `tests/recovery/`, `tests/backup/`) or by type.
- `home/amaterasu.nix` (232 lines): move the T3 Code theme and persistence into `features/desktop/t3code.nix`, and split fcitx5, SSH, smartcard and git signing into features.
- Oversized files, in order of value:
  1. `modules/nixos/vrising/options.nix` (781 lines): split by section.
  2. `grafana.nix` (488): datasources, dashboards, alerts.
  3. `homepage.nix` (528): move the data to JSON or YAML.
  4. `n8n.nix` (383): separate workflow import machinery from the service.
  5. `hyprland/default.nix` (392): binds, rules, monitors, exec-once.
  6. `steam-game-server.nix` (324) and `restic.nix` (277).
  7. `greetd.nix` (178): split the embedded JSON, CSS and Hyprland config.
  8. `home/features/neovim/keymaps/`: merge 22 files into about 5.
  9. `diabetes/app.py` (1050 lines): split into a package.
- `README.md` repository layout table omits `devshells/`, `tests/`, `docs/` and `.forgejo/`. Update it after the restructure.

## 6. tsukuyomi: needs a decision

The machine runs Windows, is excluded from CI and `nix flake check`, and has already drifted from amaterasu (`mysql`, a host blocklist, `printing`, a different monitor name). It still costs eval time through `flake.nix:224`, the `justfile` user map, and `home/tsukuyomi.nix`.
- **Option A (recommended):** delete the host. Git history keeps it.
- Option B: move it to `hosts/archive/tsukuyomi/` and drop the flake entry.
- Option C: keep it, and wire it back into CI.

## 7. Suggested order

Each step is a separate commit with a dry build of amaterasu and inari first.

1. **Trivial cleanup:** remove stray files, tracked `.pyc`, dead scripts, `dns/pkgs.nix`, `chatgpt-launcher.nix`, unreferenced `.nix` files and wallpapers. Update `.gitignore`.
2. **Dead options and the neovide stack:** remove `toggles`, `themes`, `dev.path`, `korora*`, neovide, kitty, dunst, the wireless backends and the firefox module.
3. **Decide the disabled inari services** and tsukuyomi.
4. **Official modules:** `programs.tealdeer`, `programs.wlogout`, `programs.ghostty`, `pkgs.fetchurl` in avatar, `services.changedetection-io`, `services.guacamole-*`, then protonmail-bridge and llama-cpp if the trade-offs hold.
5. **Helpers:** persistence migration, `persistentUser`, container networks, `mkLlamaServer`, `writeShellApplication`.
6. **Restructure:** option declarations out of `hosts/`, one layout per inari service, scripts and tests grouped, theming merged. Do this last, because it moves paths that the earlier steps edit.
7. **Docs:** README layout table, `docs/custom-options.md`, `CLAUDE.md` file references.

Anything touching sops, ssh, firewall, hardening or backups (steps 4 and 5 for protonmail-bridge, restic and persistence) should get a security review before it is pushed. Switching to a new generation stays with you.
