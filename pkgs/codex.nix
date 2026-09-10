{
  lib,
  stdenvNoCC,
  fetchzip,
  nodejs,
  makeWrapper,
}: let
  version = "0.153.4";

  platform =
    {
      x86_64-linux = {
        package = "codex-linux-x64";
        suffix = "linux-x64";
        target = "x86_64-unknown-linux-musl";
        hash = "sha256-a01FJPU14lC+FjeCE+uzj4mIhonPdIop60lRsj3rSuk=";
      };
      aarch64-linux = {
        package = "codex-linux-arm64";
        suffix = "linux-arm64";
        target = "aarch64-unknown-linux-musl";
        hash = "sha256-O6lQvhCwo1oICZA3Kfjhag9xyLy+ynPxnKcwpd2Vp0M=";
      };
    }
    .${
      stdenvNoCC.hostPlatform.system
    }
      or (throw "Unsupported Codex platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit version;

    src = fetchzip {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
      hash = "sha256-JI106bseXr4PAtf1LSHQR4q3dyxZ936MBZwzdDmkNhk=";
    };

    platformPackage = fetchzip {
      url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}-${platform.suffix}.tgz";
      inherit (platform) hash;
    };

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      packageRoot="$out/lib/node_modules/@openai/codex"
      platformRoot="$packageRoot/node_modules/@openai/${platform.package}"

      mkdir -p "$packageRoot" "$platformRoot" "$out/bin"
      cp -R "$src/." "$packageRoot/"
      cp -R "$platformPackage/." "$platformRoot/"
      substituteInPlace "$packageRoot/bin/codex.js" \
        --replace-fail "  CODEX_MANAGED_PACKAGE_ROOT: codexPackageRoot," "" \
        --replace-fail "env[packageManagerEnvVar] = \"1\";" ""
      chmod +x "$platformRoot/vendor/${platform.target}/bin/codex"
      chmod +x "$platformRoot/vendor/${platform.target}/bin/codex-code-mode-host"

      makeWrapper ${lib.getExe nodejs} "$out/bin/codex" \
        --unset CODEX_MANAGED_PACKAGE_ROOT \
        --unset CODEX_MANAGED_BY_NPM \
        --unset CODEX_MANAGED_BY_BUN \
        --unset CODEX_MANAGED_BY_PNPM \
        --unset CODEX_MANAGED_BY_VITE_PLUS \
        --add-flags "$packageRoot/bin/codex.js"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      mkdir -p "$TMPDIR/codex-home"
      CODEX_HOME="$TMPDIR/codex-home" "$out/bin/codex" --version | grep -F "codex-cli ${version}"

      runHook postInstallCheck
    '';

    meta = {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
    };
  }
