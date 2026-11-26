# The global instructions every agent harness reads, from one place: the
# blocks in ./instructions/, which harness files they go into, and the models
# they name. Change a rule in its .md file and a model in `yomi.ai.models`.
# `just ai-sync` rewrites the blocks without a full switch; `just ai-explain`
# shows what each harness gets.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.yomi.ai;

  # Harness -> its global instruction file, relative to the home directory.
  instructionFiles = {
    claude-code = ".claude/CLAUDE.md";
    codex = ".codex/AGENTS.md";
    opencode = ".config/opencode/AGENTS.md";
    copilot = ".copilot/copilot-instructions.md";
    gemini = ".gemini/GEMINI.md";
  };

  # "@claude.cheap@" -> config.yomi.ai.models.claude.cheap
  placeholders = lib.concatLists (lib.mapAttrsToList (provider:
    lib.mapAttrsToList (role: model: {
      from = "@${provider}.${role}@";
      to = model;
    }))
  cfg.models);
  render = lib.replaceStrings (map (p: p.from) placeholders) (map (p: p.to) placeholders);
  unrendered = text: lib.length (builtins.split "@[A-Za-z]+\\.[A-Za-z]+@" text) > 1;

  enabled = lib.filterAttrs (_: block: block.enable) cfg.instructions;
  manifest = pkgs.writeText "yomi-ai-instructions.json" (builtins.toJSON {
    files = lib.mapAttrs' (harness: file:
      lib.nameValuePair file (lib.mapAttrsToList (name: block: {
        inherit name;
        inherit (block) text;
      }) (lib.filterAttrs (_: block: lib.elem harness block.harnesses) enabled)))
    instructionFiles;
    legacy = cfg.legacyMarkers;
  });
  installer = pkgs.writeShellScriptBin "yomi-ai-instructions" ''
    exec ${pkgs.python3}/bin/python3 ${./install-instructions.py} \
      ${lib.escapeShellArg config.home.homeDirectory} ${manifest}
  '';
in {
  options.yomi.ai = {
    models = mkOption {
      type = types.attrsOf (types.attrsOf types.str);
      description = ''
        Models by provider and role. Instruction blocks name them as
        `@provider.role@`; the subagent definitions and wrappers read them here.
      '';
    };

    instructions = mkOption {
      description = "Blocks written into each harness's global instruction file.";
      default = {};
      type = types.attrsOf (types.submodule ({config, ...}: {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to write this block.";
          };
          source = mkOption {
            type = types.path;
            description = "Markdown source of the block; may name models as `@provider.role@`.";
          };
          harnesses = mkOption {
            type = types.listOf (types.enum (lib.attrNames instructionFiles));
            default = lib.attrNames instructionFiles;
            description = "Harnesses whose instruction file gets the block.";
          };
          text = mkOption {
            type = types.str;
            readOnly = true;
            default = render (builtins.readFile config.source);
            defaultText = lib.literalMD "the rendered `source`";
            description = "The block as written, with model names filled in.";
          };
        };
      }));
    };

    instructionFiles = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      default = instructionFiles;
      description = "Each harness's global instruction file, relative to the home directory.";
    };

    legacyMarkers = mkOption {
      type = types.listOf types.str;
      internal = true;
      readOnly = true;
      # Blocks written by the installers this one replaced; the skill-usage
      # block is legacy only while yomi writes its own.
      default =
        ["INARI EFFICIENT DELEGATION"]
        ++ lib.optional cfg.instructions.skill-usage.enable "MANAGED SKILL USAGE";
      description = "Old block markers the installer removes.";
    };

    installInstructions = mkOption {
      type = types.package;
      readOnly = true;
      default = installer;
      defaultText = lib.literalMD "a script that writes the enabled blocks";
      description = "Writes the enabled blocks; `just ai-sync` runs it without a switch.";
    };
  };

  config = {
    yomi.ai.models = {
      claude = {
        main = lib.mkDefault "claude-opus-5-5";
        review = lib.mkDefault "claude-sonnet-5-5";
        cheap = lib.mkDefault "claude-haiku-5-5";
      };
      codex = {
        cheap = lib.mkDefault "gpt-6-luna";
        cheapEffort = lib.mkDefault "low";
      };
      opencode.main = lib.mkDefault "openai/gpt-5.3-codex";
    };

    yomi.ai.instructions = {
      skill-usage = {
        source = ./instructions/skill-usage.md;
        # The skills flake writes its own skill-usage block once its module
        # has one; two writers of one block would overwrite each other.
        enable = lib.mkDefault (!(config.home.activation ? skillUsagePolicy));
      };
      linux-test.source = ./instructions/linux-test.md;
      reliability.source = ./instructions/reliability.md;
      # Enabled by ./efficient-agents.nix on the hosts that route subagents.
      delegation = {
        source = ./instructions/delegation.md;
        enable = lib.mkDefault false;
        # It describes these three harnesses' own subagents.
        harnesses = ["claude-code" "codex" "opencode"];
      };
    };

    assertions =
      lib.mapAttrsToList (name: block: {
        assertion = !(unrendered block.text);
        message = "yomi.ai.instructions.${name}: ${toString block.source} names a model that yomi.ai.models does not define.";
      })
      enabled;

    home.packages = [installer];
    home.activation.yomiAgentInstructions = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${lib.getExe installer}
    '';
  };
}
