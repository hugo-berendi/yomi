# OpenCode MCP Setup

OpenCode is configured with Home Manager and includes several useful MCP (Model Context Protocol) servers.

## Configured MCP Servers

1. **filesystem** - Access to your projects directory (`~/projects`)
2. **github** - GitHub integration (requires `GITHUB_TOKEN` sops secret)
3. **searxng** - SearXNG search integration (requires `SEARXNG_URL` sops secret)
4. **playwright** - Browser automation with Playwright
5. **Astro docs** - Astro.build documentation access
6. **nixos** - NixOS configuration and package search

## Secrets Configuration

MCP servers use sops-nix for secret management. Add the following secrets to `home/features/cli/secrets.yaml`:

### Required Secrets

1. **GITHUB_TOKEN** - Already configured in secrets.yaml (used by git.nix)
2. **SEARXNG_URL** - SearXNG instance URL (needs to be added)

### Adding SEARXNG_URL Secret

Edit `home/features/cli/secrets.yaml`:
```bash
sops home/features/cli/secrets.yaml
```

Add:
```yaml
SEARXNG_URL: https://your-searxng-instance.com
```

Then enable the secret in `opencode.nix` by changing:
```nix
SEARXNG_URL = lib.mkIf false {
```
to:
```nix
SEARXNG_URL = lib.mkIf true {
```

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
