{
  config,
  lib,
  ...
}: {
  yomi.nginx.at.n8n.port = config.yomi.ports.n8n;

  services.n8n = {
    enable = true;
    webhookUrl = config.yomi.nginx.at.n8n.url;
    settings = {
      port = lib.mkForce config.yomi.nginx.at.n8n.port;
      userManagement = {
        authenticationMethod = "email";
      };
      ai.enabled = true;
    };
  };

  systemd.services.n8n.environment = {
    N8N_PORT = toString config.yomi.nginx.at.n8n.port;
    N8N_HOST = "127.0.0.1";
    N8N_EDITOR_BASE_URL = config.yomi.nginx.at.n8n.url;
    N8N_TEMPLATES_ENABLED = toString true;
    N8N_AI_ENABLED = toString true;
  };
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/n8n";
    }
  ];
  # }}}
}
