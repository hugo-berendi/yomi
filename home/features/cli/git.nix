{
  pkgs,
  config,
  ...
}: {
  home.packages = [pkgs.josh]; # Just One Single History

  # https://github.com/lilyinstarlight/foosteros/blob/main/config/base.nix#L163
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

    userName = "hugo-berendi";
    userEmail = "git@hugo-berendi.de";

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

      push.default = "current";
      push.autoSetupRemote = true;

      #  {{{ URL rewriting
      url."git@github.com:".insteadOf = [
        # Normalize GitHub URLs to SSH to avoid authentication issues with HTTPS.
        "https://github.com/"
        # Allows typing `git clone github:owner/repo`.
        "github:"
      ];
      #  }}}

      # {{{ Signing
      # Sign commits using ssh
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/yubikey.pub";

      # Sign everything by default
      commit.gpgsign = false;
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

  sops.secrets.GITHUB_TOKEN.sopsFile = ./secrets.yaml;

  home.shellAliases.ghub = "GH_TOKEN=$(cat ${config.sops.secrets.GITHUB_TOKEN.path}) gh";
}
