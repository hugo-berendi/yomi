{config, ...}: let
  c = config.lib.stylix.colors.withHashtag;
in {
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

      # {{{ Stylix colours
      # Stylix has no Thunderbird target. Since Supernova, Thunderbird
      # derives nearly every surface, text and border colour from the
      # --layout-* variables in messenger/layout.css (checked against 155's
      # omni.ja), so overriding those and the selection colour recolours
      # the folder pane, message list, toolbars and dialogs together.
      # Message bodies are HTML the sender styled and are left alone.
      settings."toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      userChrome = ''
        :root {
          --layout-background-0: ${c.base00} !important;
          --layout-background-1: ${c.base01} !important;
          --layout-background-2: ${c.base01} !important;
          --layout-background-3: ${c.base02} !important;
          --layout-background-4: ${c.base02} !important;

          --layout-color-0: ${c.base05} !important;
          --layout-color-1: ${c.base05} !important;
          --layout-color-2: ${c.base04} !important;
          --layout-color-3: ${c.base03} !important;

          --layout-border-0: ${c.base02} !important;
          --layout-border-1: ${c.base02} !important;
          --layout-border-2: ${c.base03} !important;

          --selected-item-color: ${c.base0D} !important;
          --selected-item-text-color: ${c.base00} !important;
          --primary: ${c.base0D} !important;
          --color-accent-primary: ${c.base0D} !important;
        }
      '';
      # }}}
    };
  };

  accounts.email.accounts.hugob.thunderbird.enable = true;

  # ~/.thunderbird used to be unpersisted, so every boot started a new, empty
  # profile. It holds saved passwords and the IMAP cache.
  yomi.persistence.at.state.apps.thunderbird.directories = [".thunderbird"];
  # }}}
}
