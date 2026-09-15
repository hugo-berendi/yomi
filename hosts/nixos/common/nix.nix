{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  nix = {
    # {{{ Package
    package = pkgs.lix;
    # }}}
    # {{{ Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
    };
    # }}}
    # {{{ Optimization
    optimise.automatic = true;
    # }}}
    # {{{ Registry
    registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    # }}}
    # {{{ Settings
    settings = let
      caches = import ../../../common/caches.nix;
    in {
      # `extra-` rather than plain `substituters`, so cache.nixos.org and its
      # key survive instead of being replaced by this list.
      extra-substituters = caches.substituters;
      extra-trusted-public-keys = caches.trustedPublicKeys;

      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
      ];

      warn-dirty = false;

      auto-optimise-store = true;

      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://smos.cachix.org"
        "https://intray.cachix.org"
        "https://playit-nixos-module.cachix.org"
        "https://cache.numtide.com"
        "https://nvf.cachix.org"
        "https://hugo-berendi.cachix.org"
      ];

      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "smos.cachix.org-1:YOs/tLEliRoyhx7PnNw36cw2Zvbw5R0ASZaUlpUv+yM="
        "intray.cachix.org-1:qD7I/NQLia2iy6cbzZvFuvn09iuL4AkTmHvjxrQlccQ="
        "playit-nixos-module.cachix.org-1:22hBXWXBbd/7o1cOnh+p0hpFUVk9lPdLRX3p5YSfRz4="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "nvf.cachix.org-1:GMQzlEPrdqVlEzWsdk/6NH9TIoRmFVMZLUfBMvNxzlo="
        "hugo-berendi.cachix.org-1:bUxGkcUJGjKZUDcSu6WvzecShvqbpxM4YvkfcbnAm2Q="
      ];
    };
    # }}}
  };
}
