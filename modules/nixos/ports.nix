{
  config,
  lib,
  ...
}: {
  options.yomi.ports = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.port;
    description = "Fixed port allocation for Yomi services. Each service sets its own entries next to its definition.";
  };

  config.assertions = let
    byPort = lib.groupBy (name: toString config.yomi.ports.${name}) (lib.attrNames config.yomi.ports);
    clashes = lib.filterAttrs (_: names: lib.length names > 1) byPort;
  in [
    {
      assertion = clashes == {};
      message =
        "yomi.ports entries share a port number; give each its own: "
        + lib.concatStringsSep "; " (lib.mapAttrsToList (port: names: "${port} (${lib.concatStringsSep ", " names})") clashes);
    }
  ];

  # {{{ Allocation
  # Only ports that more than one host or a shared module reads live here.
  # Every other service declares its own port next to its definition, in
  # hosts/nixos/<host>/services/; the assertion above still sees them all.
  config.yomi.ports = {
    iocaine = lib.mkDefault 8420;
    meilisearch = lib.mkDefault 8434;
    opencode = lib.mkDefault 8487;
    syncthing = lib.mkDefault 8480;
  };
  # }}}
}
