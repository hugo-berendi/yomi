{config, ...}: {
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
      AddKeysToAgent = "yes";
    };
  };

  # {{{ Agent
  # gpg-agent is enabled on every host and hands it a keygrip through
  # services.gpg-agent.sshKeys, but it never sets enableSshSupport, so the
  # keygrip lands in ~/.gnupg/sshcontrol and nothing serves SSH. Only wsl had a
  # real agent; everywhere else SSH_AUTH_SOCK was simply unset.
  services.ssh-agent.enable = true;

  # Both agents export SSH_AUTH_SOCK, so turning on gpg-agent's SSH support
  # without turning this off gives whichever unit wins the race.
  assertions = [
    {
      assertion = !(config.services.gpg-agent.enableSshSupport && config.services.ssh-agent.enable);
      message = ''
        services.gpg-agent.enableSshSupport and services.ssh-agent.enable both
        provide SSH_AUTH_SOCK. Pick one: gpg-agent to authenticate with the
        yubikey, ssh-agent to cache ~/.ssh/id_ed25519.
      '';
    }
  ];
  # }}}

  yomi.persistence.at.state.apps.ssh.directories = [".ssh"];
}
