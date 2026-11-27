{
  pkgs,
  inputs,
}: let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  # Wrapped so T3 Code's sessions spend the subscriptions through CLIProxyAPI
  # like the terminal does; the guest has no key file and stays direct.
  proxy = (import ../home/features/cli/ai/subscription-proxy.nix).wrap pkgs;
  codex = proxy.codex (import ../home/features/cli/ai/codex-package.nix {inherit inputs pkgs;});
  claudeCode = proxy.claude (import ../home/features/cli/ai/claude-code-package.nix {inherit inputs pkgs;});
  providers = [codex claudeCode agents.opencode2 agents.copilot-cli];
  t3 = inputs.t3code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    providerPackages = providers;
  };
  skillLib = import (inputs.skills + "/nix/lib.nix") {inherit (pkgs) lib;};
  skills = skillLib.readSkills (inputs.skills + "/skills");
  targets =
    (pkgs.lib.mapAttrs (_: harness: builtins.attrNames (skillLib.forHarness harness skills)) {
      ".codex/skills" = "codex";
      ".claude/skills" = "claude-code";
      ".config/opencode/skills" = "opencode";
    })
    // {
      ".copilot/skills" = builtins.attrNames (pkgs.lib.filterAttrs (_: skill: pkgs.lib.elem "codex" skill.harnesses && pkgs.lib.elem "opencode" skill.harnesses) skills);
    };
  # The guest's agents get the Linux test policy in every harness's global
  # instructions, with the installer the pilot's Home Manager uses. The legacy
  # markers are the blocks earlier guest setups wrote.
  guestInstructions = pkgs.writeText "guest-instructions.json" (builtins.toJSON {
    files = pkgs.lib.genAttrs [".codex/AGENTS.md" ".claude/CLAUDE.md" ".config/opencode/AGENTS.md" ".copilot/copilot-instructions.md" ".gemini/GEMINI.md"] (_: [
      {
        name = "linux-test";
        text = builtins.readFile ../home/features/cli/ai/instructions/linux-test.md;
      }
    ]);
    legacy = ["MANAGED SKILL USAGE" "LINUX TESTING"];
  });
  helpers = pkgs.runCommand "t3code-test-helpers" {} ''
    mkdir -p "$out/bin" "$out/lib" "$out/share"
    cp -r ${../scripts/ops/t3code_workspace} "$out/lib/t3code_workspace"
    cp ${../scripts/ops/t3code-test-workspace.py} "$out/lib/t3code-test-workspace.py"
    cp ${../scripts/ops/t3code-test.py} "$out/lib/t3code-test.py"
    cp ${../scripts/ops/t3code-test-status.py} "$out/lib/t3code-test-status.py"
    for tool in t3code-test-workspace t3code-test t3code-test-status; do
      printf '#!${pkgs.runtimeShell}\nexport PATH=%s/bin:${pkgs.lib.makeBinPath ([pkgs.git pkgs.openssh pkgs.coreutils t3 pkgs.nodejs] ++ providers)}:$PATH\nexec ${pkgs.python3}/bin/python3 %s/lib/%s.py "$@"\n' "$out" "$out" "$tool" > "$out/bin/$tool"
      chmod +x "$out/bin/$tool"
    done
    ln -s ${inputs.skills}/skills "$out/share/agent-skills"
    cp ${guestInstructions} "$out/share/guest-instructions.json"
    cp ${../home/features/cli/ai/install-instructions.py} "$out/share/install-instructions.py"
    cp ${../hosts/nixos/inari/services/t3code/vm/rpc.mjs} "$out/share/rpc.mjs"
    cp ${pkgs.writeText "guest-skill-targets.json" (builtins.toJSON targets)} "$out/share/skill-targets.json"
  '';
in
  pkgs.buildEnv {
    name = "t3code-tools";
    paths = [t3 helpers pkgs.nodejs] ++ providers;
    meta.mainProgram = "t3";
    passthru = {inherit providers;};
  }
