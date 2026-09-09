_: {
  programs.notmuch = {
    enable = true;
    hooks = {
      preNew = "mbsync --all";
    };
  };

  # {{{ hugob
  accounts.email.accounts.hugob.notmuch = {
    enable = true;
    neomutt.enable = true;
  };
  # }}}
}
