{
  lib,
  fetchurl,
  runCommand,
  buildFHSEnv,
  writeShellScript,
  providerPackages ? [],
}: let
  version = "0.1.2";
  release =
    runCommand "t3code-release-${version}" {
      src = fetchurl {
        url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/t3-${version}-linux-x64.tar.gz";
        sha256 = "7aed625cb961938df174c1a067c0f05235360940b53e882a1643126b754da16c";
      };
    } ''
      mkdir -p "$out"
      tar -xzf "$src" --strip-components=1 -C "$out"
    '';
in
  # Keep the upstream single-executable bundle intact: ELF rewriting corrupts it.
  # The FHS runtime also supplies the libraries needed by bundled native modules.
  (buildFHSEnv {
    name = "t3";
    targetPkgs = p:
      [
        p.glibc
        p.stdenv.cc.cc.lib
        p.openssl
        p.zlib
        # T3 downloads Chromium itself; its shared libraries must be in this FHS runtime.
        p.glib
        p.nspr
        p.nss
        p.atk
        p.at-spi2-atk
        p.at-spi2-core
        p.dbus
        p.libx11
        p.libxcomposite
        p.libxdamage
        p.libxext
        p.libxfixes
        p.libxrandr
        p.libgbm
        p.expat
        p.libxcb
        p.libxkbcommon
        p.systemd
        p.alsa-lib
      ]
      ++ providerPackages;
    runScript = writeShellScript "t3-with-providers" ''
      export PATH=${lib.makeBinPath providerPackages}:$PATH
      exec ${release}/t3 "$@"
    '';
    meta = {
      description = "T3 Code official release with a NixOS runtime";
      homepage = "https://github.com/pingdotgg/t3code";
      license = lib.licenses.mit;
      mainProgram = "t3";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }).overrideAttrs (_: {
    pname = "t3code";
    inherit version;
  })
