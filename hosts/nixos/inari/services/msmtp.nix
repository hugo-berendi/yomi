{config, ...}: {
  # {{{ Secrets
  # Readable by every user, because sendmail runs as whoever sends (kodama as
  # its own user, ZED as root), and /etc/msmtprc points each at these files.
  # Nobody but sops-nix writes them.
  sops.secrets = {
    msmtp_aliases = {
      sopsFile = ../secrets.yaml;
      mode = "0444";
    };
    msmtp_password = {
      sopsFile = ../secrets.yaml;
      mode = "0444";
    };
  };
  # }}}

  programs.msmtp = {
    enable = true;
    setSendmail = true;

    defaults = {
      aliases = config.sops.secrets.msmtp_aliases.path;
      tls = "on";
      tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
      tls_starttls = "off";
      port = 465;
    };
    accounts = {
      default = {
        auth = "login";
        host = "smtp.migadu.com";
        passwordeval = "cat ${config.sops.secrets.msmtp_password.path}";
        user = "no-reply@tengu.hugo-berendi.de";
        from = "no-reply@tengu.hugo-berendi.de";
      };
    };
  };
}
