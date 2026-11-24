{
  inputs,
  pkgs,
  providerPackages,
}: let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  version = "0.1.7";
  src = pkgs.fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${version}";
    hash = "sha256-oQLmDCDuJPNBsf8MHMD2xhMq+CF6L836/PQesM91Clw=";
  };
  # Remove this override once llm-agents packages 0.1.7 or newer.
  unwrapped = agents.t3code.unwrapped.overrideAttrs (old: let
    resourceMonitor = old.passthru.resourceMonitor.overrideAttrs {
      inherit version src;
    };
  in {
    inherit version src;
    pnpmDeps = old.pnpmDeps.overrideAttrs {
      inherit version src;
      outputHash = "sha256-hVpxbHZ5syedAc1Zc20TkxSgB6VA3XQGubQMx6e0njA=";
    };
    # Upstream interpolates these values before overrideAttrs runs.
    preBuild = builtins.replaceStrings ["update-release-package-versions.ts ${old.version}"] ["update-release-package-versions.ts ${version}"] old.preBuild;
    installPhase = builtins.replaceStrings [(toString old.passthru.resourceMonitor)] [(toString resourceMonitor)] old.installPhase;
    passthru = old.passthru // {inherit resourceMonitor;};
  });
in
  agents.t3code.override {
    inherit providerPackages;
    t3code-unwrapped = unwrapped;
  }
