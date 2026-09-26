{config, ...}: {
  # {{{ Thunderbird
  # home-manager owns the profile: profiles.ini, and a user.js that sets up
  # the accounts from accounts.email, including the account's gpg block.
  programs.thunderbird = {
    enable = true;
    profiles.${config.yomi.pilot.name} = {
      isDefault = true;

      # Thunderbird's own OpenPGP (RNP) cannot use a smartcard. This lets it
      # sign through GnuPG, whose subkeys are on the YubiKey. Thunderbird's
      # key manager still has to have the public key (pilot.asc) imported once.
      withExternalGnupg = true;
    };
  };

  accounts.email.accounts.hugob.thunderbird.enable = true;

  # ~/.thunderbird used to be unpersisted, so every boot started a new, empty
  # profile. It holds saved passwords and the IMAP cache.
  yomi.persistence.at.state.apps.thunderbird.directories = [".thunderbird"];
  # }}}
}
