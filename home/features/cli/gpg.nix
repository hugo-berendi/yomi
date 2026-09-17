{
  pkgs,
  config,
  ...
}: {
  services.gpg-agent = {
    enable = true;

    # sshKeys = [config.yomi.pilot.gpgKeygrip] used to sit here, but without
    # enableSshSupport it only wrote the keygrip to ~/.gnupg/sshcontrol and
    # nothing served SSH -- it read as though the yubikey were an ssh agent
    # while SSH_AUTH_SOCK was unset on every host. features/cli/ssh.nix runs a
    # plain ssh-agent instead, and asserts the two are never both enabled.
    #
    # To hand ssh back to the yubikey: set enableSshSupport and sshKeys here,
    # turn off services.ssh-agent, and add the yubikey's ssh public key to
    # users.users.<pilot>.openssh.authorizedKeys -- it is not authorized on any
    # host today, so the switch would otherwise lock ssh out.

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
        source = ./yubikey_pub;
        trust = "ultimate";
      }
    ];
  };

  yomi.persistence.at.state.apps.gpg.directories = [".gnupg"];
}
