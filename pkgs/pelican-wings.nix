{pkgs}: let
  arch =
    if pkgs.stdenv.isx86_64
    then "amd64"
    else if pkgs.stdenv.isAarch64
    then "arm64"
    else throw "Unsupported architecture for Pelican Wings: ${pkgs.stdenv.system}";

  pelican-wings = pkgs.stdenv.mkDerivation rec {
    pname = "pelican-wings";
    version = "v1.0.0-beta11";

    src = pkgs.fetchurl {
      url = "https://github.com/pelican-dev/wings/releases/download/${version}/wings_linux_${arch}";
      sha256 = "1s5fs0wka350fw7dlg8rzvgb20qzx1fs68dzx81d0gqaa9q7a6z1";
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
