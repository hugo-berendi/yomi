{config, ...}: {
  # {{{ Storage & persistence
  accounts.email.maildirBasePath = "${config.xdg.dataHome}/maildir";
  yomi.persistence.at.data.apps.mail.directories = [config.accounts.email.maildirBasePath];
  # }}}
}
