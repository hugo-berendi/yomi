{
  lib,
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
      # The signing subkey is only on the YubiKey, so hosts without it
      # (inari, wsl) would fail every commit if signing were on. Hosts that
      # have the card turn it on (home/amaterasu.nix).
      gpg.format = "openpgp";
      user.signingkey = config.yomi.pilot.gpgKey;
      commit.gpgsign = lib.mkDefault false;
      tag.gpgsign = lib.mkDefault false;
      # }}}
    };
  };

  # {{{ Github cli
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };

  # GH_TOKEN below is only exported from *interactive* shell init, so anything
  # started outside a terminal -- the t3code desktop app, systemd user units,
  # and every agent they spawn -- ran gh unauthenticated. Render gh's own
  # credential file from the same sops secret so gh is logged in for any
  # process running as the pilot, however it was launched.
  # The rendered file is read-only on purpose: the login is declarative, so
  # `gh auth login`/`logout` are meant to fail rather than silently diverge.
  sops.templates."gh-hosts.yml".content = builtins.toJSON {
    "github.com" = {
      user = config.yomi.pilot.githubUser;
      oauth_token = config.sops.placeholder.GITHUB_TOKEN;
      git_protocol = "ssh";
      users.${config.yomi.pilot.githubUser}.oauth_token = config.sops.placeholder.GITHUB_TOKEN;
    };
  };

  xdg.configFile."gh/hosts.yml".source =
    config.lib.file.mkOutOfStoreSymlink config.sops.templates."gh-hosts.yml".path;

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
