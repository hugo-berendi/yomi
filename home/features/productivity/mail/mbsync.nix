_: {
  programs.mbsync.enable = true;
  services.mbsync.enable = true;

  # {{{ hugob
  accounts.email.accounts.hugob.mbsync = {
    enable = true;
    create = "both"; # sync folders both ways
    expunge = "maildir"; # Delete messages when the local dir says so
    # Bridge shows every message again under "All Mail" and once per label
    # under "Labels/…". Syncing those would store the mailbox several times.
    patterns = ["*" "!All Mail" "!Labels" "!Labels/*"];
  };
  # }}}
}
