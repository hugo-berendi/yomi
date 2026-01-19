{
  config,
  lib,
  ...
}: {
  yomi.nginx.at.warden.port = config.yomi.ports.vaultwarden;

  # {{{ Secrets
  sops.secrets.vaultwarden_env = {
    sopsFile = ../secrets.yaml;
    owner = config.users.users.vaultwarden.name;
    group = config.users.users.vaultwarden.group;
  };
  # }}}
  # {{{ General config
  services.vaultwarden = {
    enable = true;
    environmentFile = config.sops.secrets.vaultwarden_env.path;
    config = {
      DOMAIN = "https://${config.yomi.nginx.at.warden.host}";
      ROCKET_PORT = config.yomi.nginx.at.warden.port;
      ROCKET_ADDRESS = "127.0.0.1";

      SIGNUPS_ALLOWED = true;
      SHOW_PASSWORD_HINT = false;

      SMTP_SECURITY = "force_tls";
      SMTP_PORT = 465;
      SMTP_HOST = "smtp.migadu.com";
      SMTP_FROM = "vaultwarden@tengu.hugo-berendi.de";
      SMTP_USERNAME = "vaultwarden@tengu.hugo-berendi.de";
    };
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/bitwarden_rs";
      mode = "u=rwx,g=,o=";
      user = config.users.users.vaultwarden.name;
      group = config.users.users.vaultwarden.group;
    }
  ];
  # }}}
  # {{{ Hardening
  systemd.services.vaultwarden.serviceConfig =
    config.yomi.hardening.presets.standard
    // {
      ReadWritePaths = ["/var/lib/bitwarden_rs"];
    };
  # }}}
}
