{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.yomi.ai.mcp;
  cfgRemote = config.yomi.ai.mcpRemote;

  toOpencodeMcp = name: value: {
    ${name} = {
      type = "local";
      enabled = true;
      command = [value.command] ++ value.args;
    };
  };

  toOpencodeRemoteMcp = name: value: {
    ${name} = {
      type = "remote";
      enabled = true;
      url = value.url;
    };
  };

  mcpServers =
    lib.foldl' (acc: name: acc // toOpencodeMcp name cfg.${name}) {} (builtins.attrNames cfg)
    // lib.foldl' (acc: name: acc // toOpencodeRemoteMcp name cfgRemote.${name}) {} (builtins.attrNames cfgRemote);

  # {{{ Formatter Packages
  formatterPackages = with pkgs; [
    alejandra
    stylua
    prettierd
    biome
    ruff
    rustfmt
    gofumpt
    yamlfmt
    taplo
    shfmt
  ];
  # }}}
in {
  home.packages = formatterPackages;
  programs.opencode = {
    enable = true;
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;

    settings = {
      # {{{ MCP Servers
      mcp = mcpServers;
      # }}}

      # {{{ Permissions - Allow skills, safe bash commands
      permission = {
        skill."*" = "allow";
        bash = {
          "*" = "allow";
          "git push*" = "ask";
          "git reset --hard*" = "ask";
          "just nixos-rebuild switch*" = "ask";
          "rm -rf*" = "ask";
          "sudo*" = "ask";
        };
      };
      # }}}

      # {{{ Compaction - Auto-compact and prune for efficiency
      compaction = {
        auto = true;
        prune = true;
      };
      # }}}

      # {{{ Formatter Configuration
      formatter = {
        alejandra = {
          command = ["${lib.getExe pkgs.alejandra}" "$FILE"];
          extensions = [".nix"];
        };
        stylua = {
          command = ["${lib.getExe pkgs.stylua}" "$FILE"];
          extensions = [".lua"];
        };
        prettierd = {
          command = ["${lib.getExe pkgs.prettierd}" "$FILE"];
          extensions = [".js" ".jsx" ".ts" ".tsx" ".astro" ".css" ".scss" ".html" ".md" ".mdx" ".graphql"];
        };
        biome = {
          command = ["${lib.getExe pkgs.biome}" "format" "--write" "$FILE"];
          extensions = [".json" ".jsonc"];
        };
        ruff = {
          command = ["${lib.getExe pkgs.ruff}" "format" "$FILE"];
          extensions = [".py" ".pyi"];
        };
        rustfmt = {
          command = ["${lib.getExe pkgs.rustfmt}" "$FILE"];
          extensions = [".rs"];
        };
        gofumpt = {
          command = ["${lib.getExe pkgs.gofumpt}" "-w" "$FILE"];
          extensions = [".go"];
        };
        yamlfmt = {
          command = ["${lib.getExe pkgs.yamlfmt}" "$FILE"];
          extensions = [".yaml" ".yml"];
        };
        taplo = {
          command = ["${lib.getExe pkgs.taplo}" "format" "$FILE"];
          extensions = [".toml"];
        };
        shfmt = {
          command = ["${lib.getExe pkgs.shfmt}" "-w" "$FILE"];
          extensions = [".sh" ".bash"];
        };
      };
      # }}}

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

      # {{{ Agent Configuration
      agent = {
        build = {
          prompt = ''
            You are an expert NixOS and home-manager configuration assistant.

            ## CRITICAL: Use Skills First
            Before ANY task, check available skills and load relevant ones:
            - brainstorming: Before creating features/modules
            - systematic-debugging: When encountering errors
            - test-driven-development: Before implementing features
            - verification-before-completion: Before claiming work is done
            - writing-plans: For multi-step tasks

            ## MCP Tool Usage
            Use MCP tools proactively:
            - nixos: ALWAYS search packages/options before writing Nix code
            - context7: Get up-to-date library documentation
            - github: Repository operations, PRs, issues
            - deepwiki: Documentation for GitHub projects
            - exa/searxng: Web search for research
            - sequential-thinking: For complex multi-step reasoning
            - memory: Store important decisions across sessions

            ## NixOS Workflow
            1. Search nixos MCP for packages/options FIRST
            2. Check existing patterns in similar modules
            3. Write code following AGENTS.md conventions
            4. Build with: just nixos-rebuild build <host>
            5. Check formatting: just lint
            6. Only switch after successful build

            ## Code Quality
            - Follow fold marker conventions: # {{{ Section Name
            - Use yomi.* namespace for custom options
            - No comments unless explicitly requested
            - Match existing patterns in the codebase
          '';
        };

        plan = {
          prompt = ''
            You are a planning assistant for NixOS configuration.

            ## Skills for Planning
            Load relevant skills:
            - brainstorming: For exploring approaches
            - writing-plans: For detailed implementation plans

            ## MCP Tools for Research
            - nixos: Search packages and options
            - context7: Get library documentation
            - deepwiki: GitHub project docs
            - exa/searxng: Web research

            ## Planning Approach
            1. Understand the current state (check files, modules)
            2. Research solutions using MCP tools
            3. Propose 2-3 approaches with trade-offs
            4. Recommend the best approach with reasoning
            5. Create actionable implementation steps
          '';
        };

        general = {
          prompt = ''
            You are a general-purpose assistant for NixOS tasks.

            Use skills when they apply - even 1% chance means load it.
            Use MCP tools proactively:
            - nixos for packages/options
            - context7 for documentation
            - github for repository operations

            Follow AGENTS.md conventions for this codebase.
          '';
        };

        explore = {
          prompt = ''
            You are a fast exploration assistant.

            Use MCP tools for quick lookups:
            - nixos: Search packages and options
            - context7: Get documentation
            - deepwiki: GitHub project docs
            - github: Browse repositories

            Be concise - return relevant findings quickly.
          '';
        };
      };
      # }}}

      # {{{ File Watcher Ignore
      watcher = {
        ignore = [
          "result"
          "result-*"
          ".git/**"
          "*.qcow2"
          ".direnv/**"
        ];
      };
      # }}}
    };
  };

  yomi.persistence.at.state.apps.opencode.directories = ["${config.home.homeDirectory}/.local/share/opencode"];

  # {{{ Skills
  xdg.configFile."opencode/skills/frontend-design/SKILL.md".text = ''
    ---
    name: frontend-design
    description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
    license: Complete terms in LICENSE.txt
    ---

    This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

    The user provides frontend requirements: a component, page, application, or interface to build. They may include context about the purpose, audience, or technical constraints.

    ## Design Thinking

    Before coding, understand the context and commit to a BOLD aesthetic direction:
    - **Purpose**: What problem does this interface solve? Who uses it?
    - **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. There are so many flavors to choose from. Use these for inspiration but design one that is true to the aesthetic direction.
    - **Constraints**: Technical requirements (framework, performance, accessibility).
    - **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

    **CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity.

    Then implement working code (HTML/CSS/JS, React, Vue, etc.) that is:
    - Production-grade and functional
    - Visually striking and memorable
    - Cohesive with a clear aesthetic point-of-view
    - Meticulously refined in every detail

    ## Frontend Aesthetics Guidelines

    Focus on:
    - **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics; unexpected, characterful font choices. Pair a distinctive display font with a refined body font.
    - **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
    - **Motion**: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Use Motion library for React when available. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions. Use scroll-triggering and hover states that surprise.
    - **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Diagonal flow. Grid-breaking elements. Generous negative space OR controlled density.
    - **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Add contextual effects and textures that match the overall aesthetic. Apply creative forms like gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, custom cursors, and grain overlays.

    NEVER use generic AI-generated aesthetics like overused font families (Inter, Roboto, Arial, system fonts), cliched color schemes (particularly purple gradients on white backgrounds), predictable layouts and component patterns, and cookie-cutter design that lacks context-specific character.

    Interpret creatively and make unexpected choices that feel genuinely designed for the context. No design should be the same. Vary between light and dark themes, different fonts, different aesthetics. NEVER converge on common choices (Space Grotesk, for example) across generations.

    **IMPORTANT**: Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details. Elegance comes from executing the vision well.

    Remember: Claude is capable of extraordinary creative work. Don't hold back, show what can truly be created when thinking outside the box and committing fully to a distinctive vision.
  '';
  # }}}
}
