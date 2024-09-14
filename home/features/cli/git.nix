{pkgs, ...}: {
  home.packages = [pkgs.josh]; # Just One Single History

  # https://github.com/lilyinstarlight/foosteros/blob/main/config/base.nix#L163
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    userName = "hugo-berendi";
    userEmail = "hugo.berendi@outlook.de";

    # {{{ Delta pager
    delta = {
      enable = true;
      options = {};
    };
    # }}}
    # {{{ Globally ignored files
    ignores = [
      # Syncthing
      ".stfolder"
      ".stversions"

      # Direnv
      ".direnv"
      ".envrc"
    ];
    # }}}
    # {{{ Aliases
    aliases = {
      # Print history nicely
      graph = "log --decorate --oneline --graph";

      # Print last commit's hash
      hash = "log -1 --format='%H'";

      # Count the number of commits
      count = "rev-list --count --all";

      # Pull with rebase enabled
      rp = "pull --rebase";
    };
    # }}}

    extraConfig = {
      github.user = "hugo-berendi";
      hub.protocol = "ssh";
      core.editor = "nvim";
      init.defaultBranch = "main";
      rebase.autoStash = true;

      # {{{ Signing
      # Sign commits using ssh
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";

      # Sign everything by default
      commit.gpgsign = true;
      tag.gpgsign = true;
      # }}}
    };
  };

  # {{{ Github cli
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };
  # }}}
}
