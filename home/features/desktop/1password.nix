_: {
  # {{{ App
  # The app comes from programs._1password-gui (hosts/nixos/common/cli/1password.nix);
  # here it only starts with the session, minimised. It has to be running for
  # the SSH agent and for `op` to unlock through it.
  systemd.user.services."1password" = {
    Unit = {
      Description = "1Password";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/1password --silent";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  # Vault cache and settings; without these the BTRFS rollback signs the app
  # out on every boot.
  yomi.persistence.at.state.apps."1password".directories = [".config/1Password"];
  # }}}

  # {{{ SSH agent
  # ssh asks 1Password first and falls back to the IdentityFile list, so the
  # YubiKey's FIDO2 key keeps working whether or not 1Password holds a key.
  # A key stored in 1Password only opens a host once its public half is in
  # hosts/nixos/common/users; that is a separate, deliberate change.
  programs.ssh.settings."*".IdentityAgent = "~/.1password/agent.sock";
  # }}}

  # {{{ Shell plugins
  # `op plugin run` hands gh a token from 1Password instead of the sops one
  # in gh/hosts.yml. Needs a one-time `op plugin init gh` to pick the item;
  # until then gh asks for it on first use.
  home.shellAliases.gh = "op plugin run -- gh";
  # }}}
}
