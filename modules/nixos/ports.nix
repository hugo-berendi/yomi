{lib, ...}: {
  options.yomi.ports = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.port;
    description = "Fixed port allocation for Yomi services";
  };
}
