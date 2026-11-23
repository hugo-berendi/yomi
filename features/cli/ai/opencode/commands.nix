_: {
  programs.opencode.settings = {
    # {{{ Custom Commands
    command = {
      nix-build = {
        template = ''
          Build the NixOS configuration for host: $ARGUMENTS
          If no host specified, use 'amaterasu'.
          Run: just nixos-rebuild build <host>
          Report any errors clearly and suggest fixes.
        '';
        description = "Build NixOS config for a host";
        agent = "build";
      };
      nix-check = {
        template = ''
          Run flake checks: just check
          This runs `nix flake check --all-systems`.
          Report any errors and suggest fixes.
        '';
        description = "Run nix flake check";
        agent = "build";
      };
      format = {
        template = ''
          Format all code in the project:
          1. Run: just fmt (formats both Nix and Lua)
          2. Report what was formatted
        '';
        description = "Format all Nix and Lua code";
        agent = "build";
      };
      pre-commit = {
        template = ''
          Run pre-commit checks:
          1. just fmt - Format all code
          2. just check - Run flake checks
          Report any issues and fix them.
        '';
        description = "Full pre-commit workflow";
        agent = "build";
      };
      add-module = {
        template = ''
          Create a new NixOS or home-manager module.
          Arguments: $ARGUMENTS (format: <type> <name>, e.g., "nixos myservice" or "home myapp")

          Follow the module pattern from AGENTS.md:
          - Use the yomi.* namespace
          - Include enable option with mkEnableOption
          - Use proper fold markers for organization
          - Check similar modules for patterns
        '';
        description = "Create a new NixOS/home-manager module";
        agent = "build";
      };
      search-nix = {
        template = ''
          Search NixOS for: $ARGUMENTS
          Use the nixos MCP server to search:
          1. Search packages matching the query
          2. Search options matching the query
          3. Present findings concisely
        '';
        description = "Search NixOS packages and options";
        agent = "plan";
      };
    };
    # }}}
  };
}
