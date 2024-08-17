{stdenv}: let
  emailHash = "b46df8890e0fa6b50a85b2ce5eabb492ddd71a03f4c33045a8fecdb090cb25e2";
in
  stdenv.mkDerivation {
    name = "avatar";
    src = builtins.fetchurl {
      url = "https://gravatar.com/avatar/${emailHash}?s=200";
      sha256 = "GeCsZZWlkpEBfqM99N9sBallkSebeh3DjyWYZirOMzU=";
    };
    unpackPhase = "true";

    installPhase = ''
      mkdir -p $out
      cp $src $out/
    '';
  }
