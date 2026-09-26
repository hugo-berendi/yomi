{
  config,
  lib,
  ...
}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      IdentityFile = config.yomi.pilot.sshIdentity;

      # The pilot's key is passphrase-protected, so without an agent every
      # outbound connection prompts again -- and on a host with no tty
      # attached it simply fails. That is how `git pull` against
      # ssh.git.hugo-berendi.de used to fall through to password auth, which
      # stopped being a fallback once PasswordAuthentication was turned off.
      AddKeysToAgent = lib.mkDefault "yes";
    };
  };

  # {{{ Agent
  # SSH authenticates with keys on disk and the YubiKey's FIDO2 resident key,
  # not through gpg-agent; the OpenPGP card is for signing and decryption only.
  services.ssh-agent.enable = true;

  # Both agents export SSH_AUTH_SOCK, so turning on gpg-agent's SSH support
  # without turning this off gives whichever unit wins the race.
  assertions = [
    {
      assertion = !(config.services.gpg-agent.enableSshSupport && config.services.ssh-agent.enable);
      message = ''
        services.gpg-agent.enableSshSupport and services.ssh-agent.enable both
        provide SSH_AUTH_SOCK. SSH is meant to go through ssh-agent here;
        leave gpg-agent's SSH support off.
      '';
    }
  ];
  # }}}

  yomi.persistence.at.state.apps.ssh.directories = [".ssh"];
}
