# Content Management System

This directory contains structured content for the yomi NixOS configuration repository. All content is stored in YAML format for easy editing and validation.

## Directory Structure

```
content/
├── services/       # Service definitions (Actual, Forgejo, etc.)
├── hosts/          # Host machine metadata
├── tools/          # Tools and software lists
├── docs/           # Documentation content
└── schemas/        # JSON schemas for validation
```

## How to Edit Content

### Services

Edit files in `content/services/` to manage service definitions. Each service has:
- `name`: Service name
- `description`: What the service does
- `url`: Link to the service's homepage
- `category`: Service category (budgeting, git-forge, media, etc.)
- `enabled`: Whether the service is currently active

### Hosts

Edit files in `content/hosts/` to manage host machine information:
- `hostname`: Machine name
- `description`: What the machine is used for
- `type`: laptop, desktop, server, etc.
- `nix_path`: Path to the NixOS configuration

### Tools

Edit files in `content/tools/` to manage tool listings:
- `category`: fundamentals, graphical, terminal, etc.
- `items`: List of tools with name, description, and URL

### Documentation

Edit files in `content/docs/` for various documentation:
- `features.yaml`: Repository features
- `pricing.yaml`: Subscription pricing information
- `todo.yaml`: Task lists

## Validation

JSON schemas in `content/schemas/` provide validation and type safety. Validate your changes with:

```bash
# Validation scripts will be added in the future
```

## Integration

The content in this directory is meant to be consumed by:
1. README generation scripts
2. Documentation builders
3. NixOS configuration generators (future)
4. Web-based CMS interfaces (future)

## Best Practices

1. **Keep it simple**: Use plain YAML syntax
2. **Validate changes**: Check your YAML syntax before committing
3. **Be consistent**: Follow the existing patterns
4. **Add descriptions**: Help others understand what you're adding
5. **Update schemas**: If you add new fields, update the JSON schema
