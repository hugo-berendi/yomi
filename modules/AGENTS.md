# Modules

Option definitions and the code that consumes them, independent of any host.

| Directory | Loaded by | Examples |
|---|---|---|
| `nixos/` | NixOS | `yomi.web`, `yomi.expose`, `yomi.ports`, `yomi.restic`, `yomi.persistence` |
| `home-manager/` | Home Manager | `yomi.monitors`, `yomi.persistence` (home side) |
| `common/` | both | `yomi.pilot`, `yomi.theming`, `yomi.terminal` |

Each directory's `default.nix` exports its modules by path
(`web = ./web.nix;`), so errors and `just where` name the real file. Add a new
module there. Every host imports all of them, so a module must do nothing
until it is enabled or used.

Options are also declared outside this directory when they belong to one
place: by a feature (`yomi.sessionMenu` in `features/wayland/wlogout.nix`),
a profile (`yomi.anubis`), or a host's own service (`yomi.diabetes`).

## Conventions

- `{config, lib, pkgs, ...}:`, then `let cfg = config.yomi.<module>; in`.
- `lib.mkOption` always with `type` and `description`; `lib.mkEnableOption`
  for toggles; `lib.mkDefault` for values a host may override.
- When a default is computed from other settings, give it a `defaultText`
  (`lib.literalExpression "config.yomi.ports.<name>"`): the generated
  reference cannot evaluate it without a real entry.
- Gate configuration with `lib.mkIf cfg.enable`.
- camelCase option names, kebab-case package names.
- Fold markers: `# {{{ Section` / `# }}}`.
- JSON through `builtins.toJSON` and `pkgs.writeText`, never a shell heredoc.
- An assertion message names what is wrong and how to fix it, e.g. the
  clashing ports and their entries.
- A module used by several hosts takes a `sopsFile` option. A relative path
  resolves against the module's own directory, not the host's: the symptom is
  `sops-install-secrets: the key '<name>' cannot be found`.
- Wrappers around upstream services keep the upstream namespace:
  `services.vrising`, `services.steamGameServers`, `services.windrose`,
  `services.pounce`.

After adding or changing an option, run `just docs` to regenerate
`docs/options.md`; `nix flake check` fails while it is stale.
