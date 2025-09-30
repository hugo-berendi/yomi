# Content Management Guide

This guide explains how to edit and manage content in the yomi repository using the content management system.

## Overview

All editable content in this repository is now stored in structured YAML files in the `content/` directory. This makes it easy for non-technical users to manage content without touching code.

## Quick Start

1. **Navigate to the content directory**: `cd content/`
2. **Find the content you want to edit**:
   - Services: `content/services/services.yaml`
   - Hosts: `content/hosts/hosts.yaml`
   - Tools: `content/tools/tools.yaml`
   - Documentation: `content/docs/*.yaml`
3. **Edit the YAML file** using any text editor
4. **Validate your changes** (see Validation section below)
5. **Commit and push** your changes

## Content Types

### Services (`content/services/services.yaml`)

Manage the list of services running in the homelab:

```yaml
services:
  - name: Actual
    description: budgeting tool
    url: https://actualbudget.org/
    category: budgeting
    enabled: true
```

**Fields:**
- `name` (required): The service name
- `description` (required): What the service does
- `url`: Link to the service homepage
- `category` (required): Service category (see schema for valid options)
- `enabled`: Whether the service is currently active (true/false)
- `notes`: Any additional notes

### Hosts (`content/hosts/hosts.yaml`)

Manage information about host machines:

```yaml
hosts:
  - hostname: amaterasu
    description: my personal laptop
    type: laptop
    nix_path: ./hosts/nixos/amaterasu/
    mythology_reference: Japanese sun goddess
    active: true
```

**Fields:**
- `hostname` (required): Machine name
- `description` (required): What the machine is for
- `type` (required): laptop, desktop, server, phone, or other
- `nix_path`: Path to NixOS configuration
- `mythology_reference`: The mythology reference for the name
- `active`: Whether this host is actively maintained
- `notes`: Any additional notes

### Tools (`content/tools/tools.yaml`)

Manage lists of tools organized by category:

```yaml
fundamentals:
  - name: Nixos
    description: nix based operating system
    url: http://nixos.org/
    category: fundamentals
```

**Categories:**
- `fundamentals`: Core system tools
- `graphical`: GUI applications
- `terminal`: Terminal applications
- `hall_of_fame`: Previously used tools

**Fields:**
- `name` (required): Tool name
- `description` (required): What the tool does
- `url`: Link to homepage
- `category`: Tool category
- `config_path`: Path to configuration file
- `notes`: Additional notes

### Documentation

#### Features (`content/docs/features.yaml`)

Repository features and capabilities.

#### Pricing (`content/docs/pricing.yaml`)

Subscription costs and pricing information.

#### TODO (`content/docs/todo.yaml`)

Task list and priorities:

```yaml
tasks:
  - title: configure rpi iso image + nixos config
    completed: false
    priority: medium
```

## Validation

All content follows JSON schemas defined in `content/schemas/`. Before committing changes:

1. **Check YAML syntax**: Use a YAML linter or validator
2. **Verify against schema**: Ensure required fields are present
3. **Test locally**: If possible, test that your changes work

### Using yamllint (optional)

```bash
# Install yamllint
pip install yamllint

# Validate a file
yamllint content/services/services.yaml

# Validate all content
yamllint content/
```

## Adding New Content

### Adding a New Service

1. Open `content/services/services.yaml`
2. Add a new entry under `services:`:
   ```yaml
   - name: MyService
     description: A new service
     url: https://example.com
     category: other
     enabled: true
   ```
3. Save and commit

### Adding a New Host

1. Open `content/hosts/hosts.yaml`
2. Add a new entry under `hosts:`:
   ```yaml
   - hostname: newhost
     description: A new machine
     type: server
     active: true
   ```
3. Save and commit

### Adding a New Tool

1. Open `content/tools/tools.yaml`
2. Find the appropriate category section
3. Add a new entry:
   ```yaml
   - name: NewTool
     description: A helpful tool
     url: https://example.com
     category: terminal
   ```
4. Save and commit

## Best Practices

1. **Keep descriptions concise**: One line is usually enough
2. **Always include URLs**: Links help others learn about the tool/service
3. **Use consistent formatting**: Follow the existing patterns
4. **Mark inactive items**: Set `enabled: false` or `active: false` instead of deleting
5. **Add notes for context**: Use the `notes` field for important information
6. **Validate before committing**: Check your YAML syntax

## Future Enhancements

The content management system will be enhanced with:

- **Web-based CMS interface**: Edit content through a web UI
- **Automatic validation**: CI/CD checks for schema compliance
- **README generation**: Auto-generate README from content files
- **Search functionality**: Quickly find services and tools
- **Import/Export**: Convert between formats

## Troubleshooting

### YAML Syntax Errors

If you get YAML errors:
- Check indentation (use spaces, not tabs)
- Ensure colons have a space after them: `key: value`
- Use quotes for special characters: `description: "Has: special chars"`
- Validate online: https://www.yamllint.com/

### Schema Validation Errors

If content doesn't match the schema:
- Check required fields are present
- Verify category values are from allowed list
- Ensure URLs are valid

### Need Help?

- Check `content/README.md` for structure overview
- Review schemas in `content/schemas/`
- Look at existing examples in the YAML files
- Ask in repository issues or discussions

## Summary

The content management system makes it easy to:
- ✅ Edit content without touching code
- ✅ Keep content organized and validated
- ✅ Enable non-technical contributions
- ✅ Maintain consistency across the repository
- ✅ Support future automation and tooling

Happy editing! 🎉
