# claude-code from llm-agents, pinned ahead when llm-agents lags the release.
# Once llm-agents catches up (its version >= `version`), its package is used
# unchanged and this pin can be deleted.
{
  inputs,
  pkgs,
}: let
  inherit (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}) claude-code;
  version = "2.1.321";
  # sha256 from the release manifest: platforms.linux-x64.checksum
  # https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/<version>/manifest.json
  hash = "sha256:426c33815ca6645a772f722fbff10dbf2cbdb124a8aeab733c1365dbf8bbf61f";
in
  if builtins.compareVersions claude-code.version version >= 0
  then claude-code
  else
    claude-code.overrideAttrs {
      inherit version;
      src = pkgs.fetchurl {
        url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/linux-x64/claude";
        inherit hash;
      };
    }
