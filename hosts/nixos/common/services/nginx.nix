{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.nginx;
in {
  imports = [
    ./acme.nix
  ];

  options.yomi.nginx = {
    enable = lib.mkEnableOption "yomi's nginx integration";
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      statusPage = true;
    };
  };
}
