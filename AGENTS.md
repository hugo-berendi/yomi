# Agent Guidelines for Yomi

## Build/Lint/Test Commands
- **Build config**: `just nixos-rebuild build <hostname>` (hosts: amaterasu, tsukuyomi, inari, iso)
- **Apply locally**: `just nixos-rebuild switch` (requires sudo, defaults to current hostname)
- **Build ISO**: `just build-iso`
- **Format Lua**: `stylua .` (config in stylua.toml)
- **Update flake**: `just bump-common` (updates common inputs like nixpkgs, home-manager, etc.)
- **Garbage collection**: `just gc` (removes old generations, optimizes store)
- **DNS**: `just dns-diff` (preview), `just dns-push` (apply changes)
- **Secrets**: `just sops-rekey` (rekey all secrets.yaml files)

## Code Style

### Nix
- Use fold markers `{{{` and `}}}` to organize file sections
- Group imports with comments: `# {{{ Imports` ... `# }}}`
- Prefer `let...in` for local bindings
- Module options: always include `description`, `type`, and use `lib.mkOption`
- Use `lib.mkDefault` for overridable defaults
- Function args: destructured attrsets (`{lib, config, ...}:`)
- Attribute naming: camelCase for options, kebab-case for packages

### Lua  
- Tabs (width 4), max column 120 (see stylua.toml)
- Run `stylua .` before committing
- Use tabs consistently (no spaces for indentation)

### General
- **Match existing patterns**: check imports, frameworks, naming in neighboring files
- **Secrets**: never commit secrets; use sops-nix (files named `secrets.yaml`)
- **No placeholders**: use actual values matching codebase conventions
- **Flake follows**: inputs should follow nixpkgs where possible
- **Hosts**: amaterasu (desktop), tsukuyomi (laptop), inari (server)
- **Persistence**: services using `DynamicUser=` don't need explicit persistence config; `/var/lib/private` is already persisted
