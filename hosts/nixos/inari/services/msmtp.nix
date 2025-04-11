{config, ...}: {
  # {{{ Secrets
  sops.secrets = {
    msmtp_aliases = {sopsFile = ../secrets.yaml;};
    msmtp_password = {sopsFile = ../secrets.yaml;};
  };
  # }}}

  programs.msmtp = {
    enable = true;
    setSendmail = true;

    defaults = {
      aliases = config.sops.secrets.msmtp_aliases.path;
      auth = "on";
      tls = "on";
      tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
      tls_starttls = "off";
      port = 465;
    };
    accounts = {
      default = {
        host = "smtp.migadu.com";
        passwordeval = "cat ${config.sops.secrets.msmtp_password.path}";
        user = "msmtp@tengu.hugo-berendi.de";
        from = "msmtp@tengu.hugo-berendi.de";
      };
    };
  };
}
