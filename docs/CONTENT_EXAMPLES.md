# Content Examples

This file provides examples of how to add different types of content to the CMS.

## Adding a Service

To add a new service to the homelab, edit `content/services/services.yaml`:

```yaml
services:
  # ... existing services ...
  
  - name: Nextcloud
    description: self-hosted cloud storage and collaboration
    url: https://nextcloud.com/
    category: sync
    enabled: true
    notes: Alternative to Syncthing for some use cases
```

### Service Categories

Available categories:
- `budgeting` - Financial tools
- `rss` - RSS readers
- `git-forge` - Git hosting
- `monitoring` - System monitoring
- `remote-access` - Remote desktop/access
- `homepage` - Dashboard/homepage tools
- `gtd` - Getting Things Done tools
- `media` - Media servers and players
- `notebook` - Notebook/documentation
- `sharing` - File/code sharing
- `irc` - IRC clients/bouncers
- `calendar` - Calendar servers
- `reddit-client` - Reddit alternatives
- `youtube-client` - YouTube alternatives
- `self-management` - Personal management systems
- `sync` - File synchronization
- `password-manager` - Password management
- `search-engine` - Search engines
- `library` - Digital libraries
- `torrent` - Torrent clients
- `authentication` - Auth services
- `ai` - AI/ML services
- `automation` - Automation tools
- `other` - Other services

## Adding a Host

To add a new host machine, edit `content/hosts/hosts.yaml`:

```yaml
hosts:
  # ... existing hosts ...
  
  - hostname: izanami
    description: my backup server
    type: server
    nix_path: ./hosts/nixos/izanami/
    mythology_reference: Japanese goddess of creation and death
    active: true
    notes: Used for offsite backups
```

### Host Types

Available types:
- `laptop` - Laptop computers
- `desktop` - Desktop/tower PCs
- `server` - Server machines
- `phone` - Mobile devices
- `other` - Other device types

## Adding a Tool

To add a new tool, edit `content/tools/tools.yaml` under the appropriate category:

```yaml
fundamentals:
  - name: Nix
    description: purely functional package manager
    url: https://nixos.org/
    category: fundamentals
    
graphical:
  - name: Alacritty
    description: GPU-accelerated terminal emulator
    url: https://alacritty.org/
    category: graphical
    config_path: ./home/features/terminal/alacritty.nix

terminal:
  - name: htop
    description: interactive process viewer
    url: https://htop.dev/
    category: terminal

hall_of_fame:
  - name: OldTool
    description: previously used tool
    url: https://example.com
    category: terminal
    notes: Replaced by NewTool
```

## Adding Documentation

### Adding Features

Edit `content/docs/features.yaml`:

```yaml
features:
  - title: New Feature Category
    description: Description of the feature set
    items:
      - feature one
      - feature two
      - feature three
```

### Updating Pricing

Edit `content/docs/pricing.yaml`:

```yaml
summary:
  total_monthly: 2.50
  currency: EUR

subscriptions:
  - name: NewService
    description: Service description
    annual_cost: 30
    url: https://example.com/
```

### Managing TODOs

Edit `content/docs/todo.yaml`:

```yaml
tasks:
  - title: New task to complete
    completed: false
    priority: high  # high, medium, or low
    
  - title: Completed task
    completed: true
    priority: medium
```

## Validation

After making changes, validate your content:

```bash
# Using the justfile
just validate-content

# Or directly with Python
python3 scripts/validate-content.py

# Or using yamllint (if installed)
yamllint content/
```

## Common Patterns

### Marking Services as Disabled

Don't delete services you're not using - mark them as disabled:

```yaml
- name: ServiceName
  description: service description
  url: https://example.com
  category: other
  enabled: false  # ← Marked as disabled
  notes: Disabled because...
```

### Adding Notes

Use the `notes` field for important context:

```yaml
- name: Whoogle
  description: search engine
  url: https://github.com/benbusby/whoogle-search
  category: search-engine
  enabled: false
  notes: "OR SearXNG - switching between search engines"
```

### Referencing Configuration Files

For tools with config files, link to them:

```yaml
- name: Neovim
  description: my editor
  url: https://neovim.io/
  category: editor
  config_path: ./home/features/neovim/default.nix
```

## Tips

1. **Be consistent**: Follow existing formatting patterns
2. **Validate early**: Check your YAML before committing
3. **Add URLs**: Help others discover the tools/services
4. **Use categories**: Choose the most appropriate category
5. **Document reasons**: Use `notes` to explain decisions
6. **Keep it simple**: Don't over-complicate entries

## Getting Help

- Check the [Content Management Guide](CONTENT_MANAGEMENT.md)
- Review the [JSON schemas](../content/schemas/)
- Look at existing content for patterns
- Ask in repository discussions/issues
