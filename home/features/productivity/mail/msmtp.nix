{...}: {
  programs.msmtp.enable = true;

  # {{{ hugob
  accounts.email.accounts.hugob.msmtp = {
    enable = true;
  };
  # }}}
}
