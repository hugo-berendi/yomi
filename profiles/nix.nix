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
    # Only nixpkgs and this flake. Pinning every input put each one's source
    # tree into the system closure (~0.5 GiB on inari), and nothing here looks
    # the others up by registry name; unpinned names still resolve through the
    # global registry.
    registry = lib.mapAttrs (_: value: {flake = value;}) {
      inherit (inputs) nixpkgs self;
    };

    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
    # }}}
    # {{{ Settings
    settings = let
      caches = import ../common/caches.nix;
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

      # Collect unreachable store paths during builds before space runs out.
      # Separate thresholds avoid repeatedly starting GC around one boundary;
      # nh clean still owns pruning old generations, and ZFS snapshots can pin
      # deleted blocks beyond the reach of Nix GC.
      min-free = 10 * 1024 * 1024 * 1024;
      max-free = 20 * 1024 * 1024 * 1024;
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
