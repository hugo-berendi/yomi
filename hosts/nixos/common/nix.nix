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
    # nh clean replaces nix.gc (the nh module warns when both run). Plain
    # `nix-collect-garbage` without options only frees unreachable paths: every
    # old system and home-manager generation stayed a GC root forever, so the
    # store only ever grew. nh drops generations older than a week while always
    # keeping the newest five, then collects.
    gc.automatic = false;
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

  # {{{ nh
  # `nh os switch` / `nh home switch` show a nix-output-monitor build view and
  # an nvd diff of what changed; the just recipes keep working as before.
  programs.nh = {
    enable = true;
    flake = "/home/${config.yomi.pilot.name}/projects/yomi";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 7d --keep 5";
    };
  };
  # }}}
}
