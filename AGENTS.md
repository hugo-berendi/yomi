# Agent Guidelines for Yomi

## Build/Lint/Test Commands
- **Build NixOS config**: `just nixos-rebuild build <hostname>` (hosts: amaterasu, tsukuyomi, inari, iso)
- **Apply config locally**: `just nixos-rebuild switch` (requires sudo)
- **Build ISO**: `just build-iso`
- **Format Lua code**: `stylua .` (config in stylua.toml)
- **Update flake inputs**: `just bump-common`
- **DNS operations**: `just dns-diff` and `just dns-push`

## Code Style

### Nix
- Use fold markers `{{{` and `}}}` for organizing sections
- Group imports logically with comments: `# {{{ Imports`, `# }}}` 
- Prefer `let...in` for local bindings
- Use `lib.mkOption` for module options with clear descriptions
- Always set `description` and `type` for options
- Use `lib.mkDefault` for overridable defaults

### Lua  
- **Formatting**: Tabs (width 4), max column 120 (see stylua.toml)
- Apply stylua config via `yomi.lua.styluaConfig = ../../../stylua.toml`

### General
- Follow existing patterns in neighboring files (check imports, frameworks, naming)
- Never commit secrets - use sops-nix for secret management
- No generic/placeholder values - match codebase conventions precisely
