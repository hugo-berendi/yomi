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
}
