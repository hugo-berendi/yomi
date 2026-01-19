# Agent Guidelines for Yomi

Yomi is a NixOS configuration flake managing personal dotfiles and system configurations across multiple hosts.

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `common/` | Shared configuration (fonts, themes, nixpkgs settings) |
| `devshells/` | Nix development shells (yomi, lua, poetry, typescript, etc.) |
| `dns/` | DNS configuration with octodns/Cloudflare |
| `home/` | Home-manager configurations (per-host and feature modules) |
| `home/features/` | Feature modules: cli, desktop, neovim, productivity, wayland |
| `hosts/nixos/` | NixOS host configurations |
| `modules/` | Custom modules (nixos, home-manager, common) |
| `overlays/` | Nix overlays |
| `pkgs/` | Custom Nix packages |
| `scripts/` | Utility bash scripts |

**Hosts:** amaterasu (desktop), tsukuyomi (laptop), inari (server), iso (installation), wsl

## Build/Lint/Test Commands

### Primary Commands
| Command | Description |
|---------|-------------|
| `just nixos-rebuild build <hostname>` | Build NixOS config (validates without applying) |
| `just nixos-rebuild switch` | Apply config locally (requires sudo) |
| `just check` | Run all flake checks (`nix flake check --all-systems`) |
| `just lint` | Check all formatting (Nix + Lua) |
| `just fmt` | Format all code (Nix + Lua) |
| `just pre-commit` | Format + flake check (run before committing) |

### Formatting
| Command | Description |
|---------|-------------|
| `nix fmt` / `just format` | Format Nix code (uses alejandra) |
| `stylua .` / `just format-lua` | Format Lua code |
| `just format-check` | Check Nix formatting without applying |
| `just format-lua-check` | Check Lua formatting without applying |

### Other Commands
| Command | Description |
|---------|-------------|
| `just build-iso` | Build custom installation ISO |
| `just bump-common` | Update common flake inputs |
| `just gc` | Garbage collection (removes old generations) |
| `just dns-diff` | Preview DNS changes |
| `just dns-push` | Apply DNS changes |
| `just sops-rekey` | Rekey all secrets.yaml files |
| `just security-audit` | Audit systemd service hardening |

### CI Workflow
CI runs on push/PR to main and checks:
1. `nix flake check --all-systems`
2. Build all host configurations (amaterasu, tsukuyomi, inari)
3. Build DNS packages
4. Nix formatting (`nix fmt -- --check`)
5. Lua formatting (`stylua --check`)

## Code Style

### Nix

**File Organization:**
- Use fold markers to organize sections: `# {{{ Section Name` and `# }}}`
- Group imports at the top with fold markers

**Function Arguments:**
- Use destructured attrsets: `{lib, config, pkgs, ...}:`
- Access config with `let cfg = config.yomi.moduleName; in`

**Module Options:**
- Always use `lib.mkOption` with `type` and `description`
- Use `lib.mkDefault` for overridable defaults
- Use `lib.mkEnableOption` for boolean toggles

**Naming Conventions:**
- camelCase for option names (`yomi.cloudflared.enableAnubis`)
- kebab-case for package names
- Custom options go under `yomi.*` namespace

**Example Module Pattern:**
```nix
{config, lib, ...}: let
  cfg = config.yomi.myModule;
in {
  options.yomi.myModule = {
    enable = lib.mkEnableOption "My module";
    setting = lib.mkOption {
      type = lib.types.str;
      description = "A setting for my module";
      default = "value";
    };
  };

  config = lib.mkIf cfg.enable {
    # configuration here
  };
}
```

**Flake Inputs:**
- Inputs should `follow` nixpkgs where possible
- Use `inputs.nixpkgs.follows = "nixpkgs";`

### Lua

**Formatting (stylua.toml):**
- Indent: Tabs (width 4)
- Max column width: 120
- Run `stylua .` before committing

**Neovim Plugins:**
- Follow LazyVim plugin spec format
- Use tables for plugin configurations

### General Guidelines

- **Match existing patterns:** Check imports, naming, and structure in neighboring files
- **No comments unless requested:** Keep code self-documenting
- **No placeholders:** Use actual values matching codebase conventions
- **Secrets:** Never commit secrets; use sops-nix (files named `secrets.yaml`)

## Secrets Management

- Uses sops-nix with age encryption
- Secret files are named `secrets.yaml`
- Keys defined in `.sops.yaml`
- Rekey with `just sops-rekey`

## Persistence

- Uses impermanence module for stateless root
- Services with `DynamicUser=true` don't need explicit persistence (`/var/lib/private` is persisted)
- Home directories use `yomi.persistence.at.{state,cache}.apps.<name>.directories`

## Agent Workflow

### Before Making Changes
1. Use nixos MCP server to search packages and options
2. Check existing patterns in similar modules
3. Understand the module structure before editing

### Building and Testing
1. **Always build first:** `just nixos-rebuild build <hostname>`
2. **Check formatting:** `just lint`
3. **Apply locally:** `just nixos-rebuild switch` (only after successful build)

### Committing
- Commit each individual change separately
- Use descriptive commit messages
- Do not batch unrelated changes
- Run `just pre-commit` before committing

## Available MCP Tools

When working on this codebase, prefer using:
- **nixos MCP:** Search NixOS packages, options, and Home Manager configurations
- **filesystem MCP:** File operations
- **github MCP:** Repository operations
- **deepwiki MCP:** Documentation lookups
