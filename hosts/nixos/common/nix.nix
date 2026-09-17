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
    };
    # }}}
  };
}
