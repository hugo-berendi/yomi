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
        inbox = "Inbox";
        sent = "Sent";
        drafts = "Drafts";
        trash = "Trash";
      };

      # gpg = {
      #   key = "0x702AA7FD444CDC73";
      #   signByDefault = true;
      # };

      passwordCommand = "cat ${config.sops.secrets.hugob_mail_pass.path}";
      primary = true;
      # }}}
      # {{{ Imap / smtp configuration
      imap = {
        host = "imap.migadu.com";
        port = 993;
      };

      smtp = {
        host = "smtp.migadu.com";
        port = 465;
      };
      # }}}
    };
    # }}}
  };
}
