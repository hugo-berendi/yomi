{
  stdenv,
  fetchurl,
}: let
  emailHash = "b46df8890e0fa6b50a85b2ce5eabb492ddd71a03f4c33045a8fecdb090cb25e2";
in
  stdenv.mkDerivation {
    name = "avatar";
    src = fetchurl {
      url = "https://gravatar.com/avatar/${emailHash}.png?size=500";
      hash = "sha256-qGLZyYtgI3C4i/T6+LngDUheRz3cgvl9Jn61LLCbFyQ=";
    };
    unpackPhase = "true";

    installPhase = ''
      mkdir -p $out
      cp $src $out/avatar.png
    '';
  }
