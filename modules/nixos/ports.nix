{
  config,
  lib,
  ...
}: {
  options.yomi.ports = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.port;
    description = "Fixed port allocation for Yomi services";
  };

  config.assertions = let
    ports = builtins.attrValues config.yomi.ports;
  in [
    {
      assertion = builtins.length ports == builtins.length (lib.unique ports);
      message = "Every yomi.ports entry must use a unique port number.";
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
