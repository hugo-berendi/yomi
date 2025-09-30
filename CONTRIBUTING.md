# Contributing to Yomi

Thank you for your interest in contributing to the yomi NixOS configuration repository!

## Content Management

This repository uses a **content management system** to make it easy for anyone to edit documentation, service lists, host information, and tool lists.

### Quick Start

1. **Edit content files** in the `content/` directory:
   - `content/services/services.yaml` - Services running in the homelab
   - `content/hosts/hosts.yaml` - Host machines
   - `content/tools/tools.yaml` - Tools and software
   - `content/docs/*.yaml` - Documentation content

2. **Validate your changes**:
   ```bash
   python3 scripts/validate-content.py
   ```

3. **Submit a pull request**

### Documentation

- **[Content Management Guide](./docs/CONTENT_MANAGEMENT.md)** - Complete guide to editing content
- **[Content Examples](./docs/CONTENT_EXAMPLES.md)** - Examples for common tasks
- **[Content README](./content/README.md)** - Overview of the content structure

### For Code Contributions

If you're contributing code (NixOS configurations, modules, etc.):

1. Follow the existing code style
2. Test your changes if possible
3. Update documentation if you're adding new features
4. Run linters and formatters:
   ```bash
   # For Lua files
   stylua .
   ```

### What You Can Contribute

#### Content (Easy - No coding required)
- Add new services to the homelab list
- Update service descriptions
- Add new tools to the tools list
- Update documentation
- Fix typos and improve clarity

#### Code (Requires NixOS knowledge)
- Add new NixOS modules
- Improve existing configurations
- Add new host configurations
- Create new overlays or packages

#### Documentation
- Improve existing guides
- Add new tutorials
- Document undocumented features
- Add examples

### Commit Messages

Please use clear, descriptive commit messages:

**Good:**
- `Add Nextcloud service to homelab`
- `Update Neovim configuration path`
- `Fix typo in content management guide`

**Not so good:**
- `update`
- `fix`
- `changes`

### Code of Conduct

- Be respectful and considerate
- Help others learn
- Provide constructive feedback
- Follow the existing patterns and conventions

### Getting Help

If you're unsure about something:
- Check the documentation in `docs/`
- Look at existing examples
- Open an issue to ask questions
- Review the schemas in `content/schemas/`

### Repository Structure

```
yomi/
├── content/           # Editable content (CMS)
│   ├── services/     # Service definitions
│   ├── hosts/        # Host information
│   ├── tools/        # Tool listings
│   ├── docs/         # Documentation content
│   └── schemas/      # JSON schemas for validation
├── docs/             # Documentation
├── home/             # Home-manager configurations
├── hosts/            # NixOS host configurations
├── modules/          # Custom NixOS modules
├── scripts/          # Utility scripts
└── flake.nix        # Nix flake entrypoint
```

### Testing Changes

For content changes:
```bash
python3 scripts/validate-content.py
```

For code changes, you'll need a NixOS environment to test properly.

## Thank You!

Every contribution, no matter how small, helps improve this project. Thank you for taking the time to contribute! 🎉
