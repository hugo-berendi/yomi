{pkgs}: let
  arch =
    if pkgs.stdenv.isx86_64
    then "amd64"
    else if pkgs.stdenv.isAarch64
    then "arm64"
    else throw "Unsupported architecture for Pelican Wings: ${pkgs.stdenv.hostPlatform.system}";

  pelican-wings = pkgs.stdenv.mkDerivation rec {
    pname = "pelican-wings";
    version = "v1.0.0-beta29";

    src = pkgs.fetchurl {
      # The project moved from pelican-dev/wings to pelican/wings.
      url = "https://github.com/pelican/wings/releases/download/${version}/wings_linux_${arch}";
      hash = "sha256-ddgezyU2btPAWtbGzLrVMu2Ja4IZqp0sk6WvAD1pAAs=";
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
