# OpenCode 2.0 keeps the protocol expected by the installed T3 release.
{
  inputs,
  pkgs,
}: let
  base = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
in
  base.overrideAttrs (old: {
    version = "2.0.32";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-2.0.32.tgz";
      hash = "sha512-Q50ofBQ3gdwjD6ZQhrVR8fVlm8D2xPMshy4dynY6l6b+qLdKgBSJ9WpoaDyrQX1YWmf2s7IN4RbXmoXXdJitDA==";
    };
    postInstall =
      (old.postInstall or "")
      + ''
        makeWrapper "$out/bin/opencode2" "$out/bin/opencode" \
        --run 'if [ -r "$HOME/.t3/opencode-server.env" ]; then set -a; . "$HOME/.t3/opencode-server.env"; set +a; fi'
      '';
    meta = old.meta // {mainProgram = "opencode";};
  })
