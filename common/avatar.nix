{stdenv}: let
  emailHash = "b46df8890e0fa6b50a85b2ce5eabb492ddd71a03f4c33045a8fecdb090cb25e2";
in
  stdenv.mkDerivation {
    name = "avatar";
    src = builtins.fetchurl {
      url = "https://gravatar.com/avatar/${emailHash}.png";
      sha256 = "09wani3p5qjg9mwqvq21adb0s38lvayf0wiafjyw5yamg5d4108d";
    };
    unpackPhase = "true";

    installPhase = ''
      mkdir -p $out
      cp $src $out/avatar.png
    '';
  }
