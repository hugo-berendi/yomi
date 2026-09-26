{
  pkgs,
  config,
  ...
}: let
  ghTokenInit = ''
        export GH_TOKEN="$(cat ${config.sops.secrets.GITHUB_TOKEN.path} 2>/dev/null)"
        if [ -n "$GH_TOKEN" ]; then
          export NIX_CONFIG="$NIX_CONFIG
    access-tokens = github.com=$GH_TOKEN"
        fi
  '';
in {
  home.packages = [pkgs.josh]; # Just One Single History

  # https://github.com/lilyinstarlight/foosteros/blob/main/config/base.nix#L163
  programs.git = {
    enable = true;
    package = pkgs.gitFull;

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

    settings = {
      user = {
        name = "hugo-berendi";
        email = config.yomi.pilot.gitEmail;
      };

      alias = {
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

      github.user = config.yomi.pilot.githubUser;
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
      user.signingkey = config.yomi.pilot.signingKey;

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

  programs.delta = {
    enable = true;
    options = {};
    enableGitIntegration = true;
  }; # }}}

  # {{{ GitHub token from sops
  sops.secrets.GITHUB_TOKEN.sopsFile = ./ai/secrets.yaml;

  programs.bash.initExtra = ghTokenInit;
  programs.fish.interactiveShellInit = ''
        set -gx GH_TOKEN (cat ${config.sops.secrets.GITHUB_TOKEN.path} 2>/dev/null)
        if test -n "$GH_TOKEN"
          set -gx NIX_CONFIG "$NIX_CONFIG
    access-tokens = github.com=$GH_TOKEN"
        end
  '';
  # }}}

  # Keep alias as fallback for explicit token usage
  home.shellAliases.ghub = "GH_TOKEN=$(cat ${config.sops.secrets.GITHUB_TOKEN.path}) gh";
}
