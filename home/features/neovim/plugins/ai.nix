{
  config,
  pkgs,
  lib,
  ...
}: let
  nn99 = pkgs.vimUtils.buildVimPlugin {
    pname = "99";
    version = "unstable-2025-02-04";
    src = pkgs.fetchFromGitHub {
      owner = "ThePrimeagen";
      repo = "99";
      rev = "master";
      hash = "sha256-TZ/5TRUN1HC8mobs9cewJ5+7cBWt0zFO4KsY6hH29GU=";
    };
    nvimSkipModule = ["99.editor.lsp"];
    meta.homepage = "https://github.com/ThePrimeagen/99";
  };

  skillsDir = "${config.xdg.configHome}/nvim/skills";
in {
  programs.nvf.settings.vim.assistant = {
    avante-nvim = {
      enable = true;
      setupOpts = {
        provider = "ollama";
        providers = {
          ollama = {
            endpoint = "http://inari:11434";
            model = "qwen2.5-coder:7b";
            timeout = 60000;
          };
        };
        behaviour = {
          auto_suggestions = false;
          auto_set_highlight_group = true;
          auto_set_keymaps = true;
          auto_apply_diff_after_generation = false;
          minimize_diff = true;
          enable_token_counting = true;
        };
        windows = {
          position = "right";
          wrap = true;
          width = 30;
          sidebar_header = {
            enabled = true;
            align = "center";
            rounded = true;
          };
        };
        hints.enabled = true;
      };
    };
  };

  # {{{ 99 Plugin Configuration
  programs.nvf.settings.vim.extraPlugins = {
    nn99 = {
      package = nn99;
      setup = ''
        local _99 = require("99")
        local cwd = vim.uv.cwd()
        local basename = vim.fs.basename(cwd)

        _99.setup({
          model = "copilot/claude-sonnet-4-5",
          logger = {
            level = _99.INFO,
            path = "/tmp/" .. basename .. ".99.debug",
            print_on_error = true,
          },
          completion = {
            custom_rules = {
              "${skillsDir}/",
            },
            source = "cmp",
          },
          md_files = {
            "AGENT.md",
            "AGENTS.md",
          },
        })

        vim.keymap.set("n", "<leader>9f", function()
          _99.fill_in_function()
        end, { desc = "[99] Fill in function" })

        vim.keymap.set("n", "<leader>9p", function()
          _99.fill_in_function_prompt()
        end, { desc = "[99] Fill in function with prompt" })

        vim.keymap.set("v", "<leader>9v", function()
          _99.visual()
        end, { desc = "[99] Visual selection" })

        vim.keymap.set("v", "<leader>9p", function()
          _99.visual_prompt()
        end, { desc = "[99] Visual with prompt" })

        vim.keymap.set("n", "<leader>9s", function()
          _99.stop_all_requests()
        end, { desc = "[99] Stop all requests" })

        vim.keymap.set("n", "<leader>9l", function()
          _99.view_logs()
        end, { desc = "[99] View logs" })

        vim.keymap.set("n", "<leader>9i", function()
          _99.info()
        end, { desc = "[99] Info" })

        vim.keymap.set("n", "<leader>9q", function()
          _99.previous_requests_to_qfix()
        end, { desc = "[99] Previous requests to quickfix" })
      '';
    };
  };
  # }}}
  # {{{ Skills Directory
  xdg.configFile = {
    "nvim/skills/nixos/SKILL.md".text = ''
      You are an expert in NixOS and the Nix language.

      ## Nix Language Guidelines
      - Use `lib.mkOption` with `type` and `description` for module options
      - Use `lib.mkEnableOption` for boolean toggles
      - Use `lib.mkDefault` for overridable defaults
      - Use `lib.mkIf` for conditional configuration
      - Use `lib.mkMerge` to combine multiple configurations
      - Prefer `lib.` prefix over `with lib;` for clarity
      - Use destructured attrsets for function arguments: `{lib, config, pkgs, ...}:`

      ## Module Structure
      - Access config with `let cfg = config.moduleName; in`
      - Custom options should go under a namespace (e.g., `yomi.*`)
      - Group imports at the top of files
      - Use camelCase for option names
      - Use kebab-case for package names

      ## NixOS Specifics
      - Services should use systemd options under `systemd.services`
      - Use `environment.systemPackages` for system-wide packages
      - Use `users.users.<name>.packages` for user-specific packages
      - Secrets should use sops-nix, never commit plain secrets

      ## Home Manager
      - Use `home.packages` for user packages
      - Use `programs.<name>.enable` for program configuration
      - Use `services.<name>.enable` for user services
      - Use `xdg.*` for XDG directory configuration
    '';

    "nvim/skills/astro/SKILL.md".text = ''
      You are an expert in Astro, a modern static site generator.

      ## Astro Guidelines
      - Use `.astro` files for components with the frontmatter (---) syntax
      - Keep JavaScript/TypeScript in the frontmatter, HTML in the template
      - Use `Astro.props` to access component props
      - Use `Astro.slots` for slot content
      - Prefer static rendering, use `client:*` directives only when needed

      ## Component Structure
      ```astro
      ---
      interface Props {
        title: string;
        description?: string;
      }
      const { title, description } = Astro.props;
      ---
      <div>
        <h1>{title}</h1>
        {description && <p>{description}</p>}
        <slot />
      </div>
      ```

      ## Client Directives
      - `client:load` - Load and hydrate immediately
      - `client:idle` - Load when browser is idle
      - `client:visible` - Load when component is visible
      - `client:media` - Load on media query match
      - `client:only` - Skip SSR, client-side only

      ## Content Collections
      - Define collections in `src/content/config.ts`
      - Use Zod schemas for type-safe frontmatter
      - Query with `getCollection()` and `getEntry()`

      ## Integrations
      - Use `@astrojs/tailwind` for Tailwind CSS
      - Use `@astrojs/mdx` for MDX support
      - Use `@astrojs/sitemap` for sitemap generation
    '';

    "nvim/skills/typescript/SKILL.md".text = ''
      You are an expert in TypeScript.

      ## Type Guidelines
      - Prefer `interface` for object shapes that may be extended
      - Use `type` for unions, intersections, and mapped types
      - Avoid `any`, use `unknown` for truly unknown types
      - Use `as const` for literal types
      - Prefer `readonly` for immutable data

      ## Function Types
      - Use explicit return types for public APIs
      - Use generics for reusable type-safe functions
      - Prefer arrow functions for callbacks
      - Use function overloads sparingly

      ## Best Practices
      - Enable strict mode in tsconfig.json
      - Use discriminated unions for state machines
      - Prefer `Map` and `Set` over plain objects for dynamic keys
      - Use `satisfies` operator for type checking without widening
      - Use template literal types for string patterns

      ## Error Handling
      - Use Result/Either pattern for expected errors
      - Use exceptions for unexpected errors
      - Create custom error classes extending Error
      - Use type guards for runtime type checking
    '';

    "nvim/skills/lua/SKILL.md".text = ''
      You are an expert in Lua, particularly for Neovim plugin development.

      ## Neovim Lua Guidelines
      - Use `vim.api` for Neovim API calls
      - Use `vim.fn` for Vimscript functions
      - Use `vim.opt` for options (replaces `set`)
      - Use `vim.keymap.set` for keymaps
      - Use `vim.cmd` for Ex commands

      ## Module Structure
      - Return a table from modules
      - Use local variables for private state
      - Expose setup function for configuration
      - Use metatables for OOP patterns

      ## Best Practices
      - Prefer `local` variables for performance
      - Use `vim.tbl_*` functions for table operations
      - Use `vim.validate` for argument validation
      - Use `pcall`/`xpcall` for error handling
      - Use `vim.schedule` for async operations

      ## Treesitter
      - Use `vim.treesitter.query.parse` for queries
      - Use `vim.treesitter.get_parser` for parsers
      - Iterate nodes with `iter_matches` or `iter_captures`
    '';

    "nvim/skills/go/SKILL.md".text = ''
      You are an expert in Go.

      ## Go Guidelines
      - Use short variable names in small scopes
      - Use descriptive names in larger scopes
      - Prefer returning errors over panicking
      - Use `context.Context` for cancellation and timeouts
      - Use interfaces for abstraction, not inheritance

      ## Error Handling
      - Always check errors: `if err != nil { return err }`
      - Wrap errors with context: `fmt.Errorf("doing x: %w", err)`
      - Use custom error types for specific error handling
      - Use `errors.Is` and `errors.As` for error checking

      ## Concurrency
      - Use goroutines for concurrent work
      - Use channels for communication
      - Use `sync.WaitGroup` for waiting on goroutines
      - Use `sync.Mutex` for protecting shared state
      - Prefer `context` for cancellation over channels

      ## Project Structure
      - Keep `main.go` minimal
      - Use internal/ for private packages
      - Use pkg/ for public packages (optional)
      - One package per directory
    '';

    "nvim/skills/python/SKILL.md".text = ''
      You are an expert in Python.

      ## Python Guidelines
      - Use type hints for function signatures
      - Use dataclasses or Pydantic for data structures
      - Use `pathlib.Path` over `os.path`
      - Use f-strings for string formatting
      - Use context managers for resource management

      ## Type Hints
      - Use `from __future__ import annotations` for forward references
      - Use `Optional[T]` or `T | None` for nullable types
      - Use `TypeVar` for generic functions
      - Use `Protocol` for structural subtyping

      ## Best Practices
      - Follow PEP 8 style guide
      - Use virtual environments
      - Use `pytest` for testing
      - Use `black` for formatting
      - Use `ruff` or `flake8` for linting

      ## Async
      - Use `async`/`await` for I/O-bound operations
      - Use `asyncio.gather` for concurrent tasks
      - Use `aiohttp` for async HTTP
    '';

    "nvim/skills/react/SKILL.md".text = ''
      You are an expert in React and modern frontend development.

      ## React Guidelines
      - Use functional components with hooks
      - Use TypeScript for type safety
      - Keep components small and focused
      - Lift state up when needed
      - Use composition over inheritance

      ## Hooks
      - `useState` for local state
      - `useEffect` for side effects (prefer alternatives when possible)
      - `useCallback` for stable function references
      - `useMemo` for expensive computations
      - `useRef` for mutable refs and DOM access
      - `useContext` for dependency injection

      ## State Management
      - Start with local state
      - Use context for low-frequency updates
      - Use Zustand/Jotai for complex client state
      - Use TanStack Query for server state

      ## Performance
      - Use React.memo sparingly
      - Use virtualization for long lists
      - Lazy load components with React.lazy
      - Use Suspense for loading states

      ## Patterns
      - Compound components for flexible APIs
      - Render props for sharing logic
      - Custom hooks for reusable stateful logic
    '';

    "nvim/skills/css/SKILL.md".text = ''
      You are an expert in CSS and modern styling approaches.

      ## CSS Guidelines
      - Use CSS custom properties (variables) for theming
      - Use logical properties (inline/block) for internationalization
      - Use CSS Grid for 2D layouts
      - Use Flexbox for 1D layouts
      - Use `clamp()` for responsive sizing

      ## Tailwind CSS
      - Use utility classes for rapid development
      - Extract components for repeated patterns
      - Use `@apply` sparingly in component files
      - Configure theme in tailwind.config.js
      - Use arbitrary values `[]` when needed

      ## Modern CSS
      - Use `:has()` for parent selection
      - Use `@container` for container queries
      - Use `@layer` for cascade management
      - Use `color-mix()` for color manipulation
      - Use `oklch()` for perceptually uniform colors

      ## Best Practices
      - Mobile-first responsive design
      - Use relative units (rem, em) over pixels
      - Ensure sufficient color contrast
      - Test with reduced motion preferences
    '';
  };
  # }}}
}
