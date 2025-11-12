# OpenCode MCP Setup

OpenCode is configured with Home Manager and includes several useful MCP (Model Context Protocol) servers.

## Configured MCP Servers

1. **filesystem** - Access to your projects directory (`~/projects`)
2. **github** - GitHub integration (requires `GITHUB_TOKEN` sops secret)
3. **searxng** - SearXNG search integration (requires `SEARXNG_URL` sops secret)
4. **exa** - Exa.ai web search integration (requires `EXA_API_KEY` sops secret)
5. **deepwiki** - DeepWiki search for documentation and knowledge bases
6. **playwright** - Browser automation with Playwright
7. **Astro docs** - Astro.build documentation access
8. **nixos** - NixOS configuration and package search

## Secrets Configuration

MCP servers use sops-nix for secret management. Add the following secrets to `home/features/cli/secrets.yaml`:

### Required Secrets

1. **GITHUB_TOKEN** - Already configured in secrets.yaml (used by git.nix)
2. **SEARXNG_URL** - SearXNG instance URL (optional)
3. **EXA_API_KEY** - Exa.ai API key for web search (optional, get from https://exa.ai)

### Adding Optional Secrets

#### Adding SEARXNG_URL Secret

Edit `home/features/cli/secrets.yaml`:
```bash
sops home/features/cli/secrets.yaml
```

Add:
```yaml
SEARXNG_URL: https://your-searxng-instance.com
```

The secret will be automatically enabled if present in secrets.yaml.

#### Adding EXA_API_KEY Secret

Edit `home/features/cli/secrets.yaml`:
```bash
sops home/features/cli/secrets.yaml
```

Add:
```yaml
EXA_API_KEY: your-exa-api-key-here
```

The secret will be automatically enabled if present in secrets.yaml. Get your API key from https://exa.ai

## Usage

After configuring secrets, rebuild and run:
```bash
just nixos-rebuild switch
opencode
```

The MCP servers will automatically be available in your OpenCode session.

## Configuration Location

- MCP config: `~/.config/opencode/mcp-servers.json` (managed by Home Manager)
- OpenCode data: `~/.local/share/opencode` (persisted via impermanence)
- Secrets: `home/features/cli/secrets.yaml` (encrypted with sops)

## Customizing MCP Servers

Edit `home/features/cli/opencode.nix` to:
- Add new MCP servers
- Modify existing server configurations
- Change filesystem paths or postgres connection strings
