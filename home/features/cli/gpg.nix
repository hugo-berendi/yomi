{
  pkgs,
  config,
  ...
}: {
  services.gpg-agent = {
    enable = true;

    # No SSH support: ssh authenticates with the YubiKey's FIDO2 resident key
    # through plain ssh-agent (features/cli/ssh.nix, which asserts the two
    # agents are never both enabled). gpg-agent only serves the OpenPGP card
    # for signing and decryption.

    pinentry.package =
      if config.gtk.enable
      then pkgs.pinentry-gnome3
      else pkgs.pinentry-curses;
    enableFishIntegration = true;
    extraConfig = ''
      no-allow-external-cache
    '';
  };

  programs.gpg = {
    enable = true;
    publicKeys = [
      {
        # yomi.pilot.gpgKey; the secret subkeys are only on the YubiKey.
        source = ./pilot.asc;
        trust = "ultimate";
      }
    ];
  };

  yomi.persistence.at.state.apps.gpg.directories = [".gnupg"];
}
