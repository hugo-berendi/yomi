{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.beszel-agent;
in {
  options.yomi.beszel-agent = {
    enable =
      lib.mkEnableOption "yomi's beszel agent"
      // {
        default = true;
      };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.beszel_agent_key.sopsFile = ../secrets.yaml;
    sops.secrets.beszel_agent_token.sopsFile = ../secrets.yaml;
    sops.templates."beszel-agent.env".content = ''
      KEY=${config.sops.placeholder.beszel_agent_key}
      TOKEN=${config.sops.placeholder.beszel_agent_token}
    '';

    services.beszel.agent = {
      enable = true;
      openFirewall = true;
      environmentFile = config.sops.templates."beszel-agent.env".path;
      environment = {
        HUB_URL = "https://monitoring.hugo-berendi.de";
      };
      smartmon.enable = true;
    };
  };
}
