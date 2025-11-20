{pkgs}: let
  arch =
    if pkgs.stdenv.isx86_64
    then "amd64"
    else if pkgs.stdenv.isAarch64
    then "arm64"
    else throw "Unsupported architecture for Pelican Wings: ${pkgs.stdenv.hostPlatform.system}";

  pelican-wings = pkgs.stdenv.mkDerivation rec {
    pname = "pelican-wings";
    version = "v1.0.0-beta19";

    src = pkgs.fetchurl {
      url = "https://github.com/pelican-dev/wings/releases/download/${version}/wings_linux_${arch}";
      hash = "sha256-JosJtqKoPPFGxEa2AnS0bZ6w3w1X4kyfozqQN6YZZOc=";
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp $src $out/bin/wings
      chmod +x $out/bin/wings
      runHook postInstall
    '';
  };
in
  pelican-wings
