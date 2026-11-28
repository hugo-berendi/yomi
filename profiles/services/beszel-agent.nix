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
    sops.templates."beszel-agent.env" = {
      # The hub tells agents apart by token, so each host appends its name to
      # the fleet's shared one; inari's services/beszel/default.nix lists the same.
      content = ''
        KEY=${config.sops.placeholder.beszel_agent_key}
        TOKEN=${config.sops.placeholder.beszel_agent_token}-${config.networking.hostName}
      '';
      restartUnits = ["beszel-agent.service"];
    };

    services.beszel.agent = {
      enable = true;
      # No inbound port: agents connect to the hub, and inari's hub reaches
      # its own agent on 127.0.0.1.
      environmentFile = config.sops.templates."beszel-agent.env".path;
      environment = {
        HUB_URL = "https://monitoring.hugo-berendi.de";
      };
      smartmon.enable = true;
    };
  };
}
