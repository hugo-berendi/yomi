{
  fetchurl,
  installShellFiles,
  pangolin-cli,
  stdenvNoCC,
  versionCheckHook,
}: let
  asset =
    {
      x86_64-linux = {
        arch = "amd64";
        hash = "sha256-+UcXa2yHIZKKRcz7AVK6zTtLdcbyEtoCku+3eZlH2Hw=";
      };
      aarch64-linux = {
        arch = "arm64";
        hash = "sha256-u1kwythr2EC+xnWXGUuDxxfH6cEd/oUasWq2Wt3mRxE=";
      };
    }.${
      stdenvNoCC.hostPlatform.system
    };
in
  stdenvNoCC.mkDerivation (final: {
    pname = "pangolin-cli";
    version = "0.23.0";
    src = fetchurl {
      url = "https://github.com/fosrl/cli/releases/download/${final.version}/pangolin-cli_linux_${asset.arch}";
      inherit (asset) hash;
    };
    dontUnpack = true;
    nativeBuildInputs = [installShellFiles];
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/pangolin"
      installShellCompletion --cmd pangolin \
        --bash <("$out/bin/pangolin" completion bash) \
        --fish <("$out/bin/pangolin" completion fish) \
        --zsh <("$out/bin/pangolin" completion zsh)
      runHook postInstall
    '';
    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];
    versionCheckKeepEnvironment = ["HOME"];
    versionCheckProgramArg = "version";
    meta = pangolin-cli.meta // {changelog = "https://github.com/fosrl/cli/releases/tag/${final.version}";};
  })
