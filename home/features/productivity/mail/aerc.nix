{...}: {
  # {{{ Aerc
  programs.aerc = {
    enable = true;
    extraConfig.general.unsafe-accounts-conf = true;
  };
  # }}}

  # {{{ hugob
  accounts.email.accounts.hugob.aerc = {
    enable = true;
  };
  # }}}
}
