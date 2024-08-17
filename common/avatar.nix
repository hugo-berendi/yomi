{stdenv}: let
  emailHash = "b46df8890e0fa6b50a85b2ce5eabb492ddd71a03f4c33045a8fecdb090cb25e2";
in
  stdenv.mkDerivation {
    name = "avatar";
    src = builtins.fetchurl {
      url = "https://gravatar.com/avatar/${emailHash}.png?size=500";
      sha256 = "090pkfq2rdby4ryzk0nw7m3mwj0dw2wziyplifw708v0ig4xjqm8";
    };
    unpackPhase = "true";

    installPhase = ''
      mkdir -p $out
      cp $src $out/avatar.png
    '';
  }
