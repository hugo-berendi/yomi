{config, ...}: {
  imports = [
    ./msmtp.nix
    ./mbsync.nix
    ./notmuch.nix
    ./aerc.nix
    ./neomutt.nix
    ./neomutt-theme.nix
    ./thunderbird.nix
    ./persistence.nix
  ];

  # {{{ Sops secrets
  sops.secrets.outlook_mail_pass.sopsFile = ../secrets.yaml;
  sops.secrets.hugob_mail_pass.sopsFile = ../secrets.yaml;
  # }}}

  accounts.email.accounts = {
    # {{{ hugob
    hugob = rec {
      # {{{ Primary config
      address = "personal@hugo-berendi.de";
      realName = "Hugo Berendi";
      userName = address;
      aliases = ["git@hugo-berendi.de"];

      folders = {
        inbox = "INBOX";
        sent = "Sent";
        drafts = "Drafts";
        trash = "Trash";
      };

      # Signs with the YubiKey's subkey. Mail is only on hosts that have the
      # card. Not encryptByDefault: that would break mail to anyone without a
      # key.
      gpg = {
        key = config.yomi.pilot.gpgKey;
        signByDefault = true;
      };

      passwordCommand = "cat ${config.sops.secrets.hugob_mail_pass.path}";
      primary = true;
      # }}}
      # {{{ Imap / smtp configuration
      # Proton Mail Bridge on inari, over the tailnet: nginx terminates TLS
      # with a real certificate and hands off to Bridge through a pinned
      # STARTTLS relay (hosts/nixos/inari/services/protonmail-bridge.nix).
      # The password is the Bridge's own (its `info` command), not the
      # Proton account password.
      imap = {
        host = "mail.hugo-berendi.de";
        port = 993;
      };

      smtp = {
        host = "mail.hugo-berendi.de";
        port = 465;
      };
      # }}}
    };
    # }}}
  };
}
