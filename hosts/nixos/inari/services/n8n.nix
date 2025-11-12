{
  config,
  lib,
  pkgs,
  ...
}: {
  yomi.nginx.at.n8n.port = config.yomi.ports.n8n;

  services.n8n = {
    enable = true;
    environment = {
      WEBHOOK_URL = config.yomi.nginx.at.n8n.url;
      N8N_PORT = toString config.yomi.nginx.at.n8n.port;
      N8N_HOST = "127.0.0.1";
      N8N_EDITOR_BASE_URL = config.yomi.nginx.at.n8n.url;
    };
  };

  systemd.services.n8n = {
    path = with pkgs; [
      nodejs
      nodePackages.npm
      git
      python3 # Für native Node-Module
      gcc # Für native Node-Module
      busybox
    ];
    environment = lib.mkIf (config.services.n8n.enable) {
      N8N_PORT = toString config.yomi.nginx.at.n8n.port;
      N8N_HOST = "127.0.0.1";
      N8N_EDITOR_BASE_URL = config.yomi.nginx.at.n8n.url;
      N8N_TEMPLATES_ENABLED = toString true;
      N8N_AI_ENABLED = toString true;
    };
  };
}
