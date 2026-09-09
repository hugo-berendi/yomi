{...}: {
  programs.mbsync.enable = true;
  services.mbsync.enable = true;

  # {{{ hugob
  accounts.email.accounts.hugob.mbsync = {
    enable = true;
    create = "both"; # sync folders both ways
    expunge = "maildir"; # Delete messages when the local dir says so
  };
  # }}}
}
