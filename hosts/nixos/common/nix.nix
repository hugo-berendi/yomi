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
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
      ];

      warn-dirty = false;

      auto-optimise-store = true;

      trusted-users = ["root" "@wheel"];

      fallback = true;
    };
    # }}}
  };
}
