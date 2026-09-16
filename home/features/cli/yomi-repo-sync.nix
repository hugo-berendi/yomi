{
  config,
  pkgs,
  lib,
  ...
}: let
  repoPath = "${config.xdg.userDirs.extraConfig.PROJECTS}/yomi";

  syncScript = pkgs.writeShellApplication {
    name = "yomi-repo-sync";
    runtimeInputs = [pkgs.git];
    text = ''
      repo="${repoPath}"

      if [[ ! -d "$repo/.git" ]]; then
        echo "yomi-repo-sync: no checkout at $repo, skipping" >&2
        exit 0
      fi

      cd "$repo"
      git fetch --quiet origin

      if [[ -n "$(git status --porcelain)" ]]; then
        echo "yomi-repo-sync: working tree is dirty, skipping pull" >&2
        exit 0
      fi

      upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || {
        echo "yomi-repo-sync: no upstream branch configured, skipping" >&2
        exit 0
      }

      if [[ -n "$(git log "$upstream"..HEAD --oneline)" ]]; then
        echo "yomi-repo-sync: local commits not yet pushed, skipping pull" >&2
        exit 0
      fi

      git merge --ff-only "$upstream"
    '';
  };
in {
  systemd.user.services.yomi-repo-sync = {
    Unit.Description = "Pull latest yomi commits into ${repoPath}";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe syncScript;
    };
  };

  systemd.user.timers.yomi-repo-sync = {
    Unit.Description = "Periodically pull latest yomi commits";
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
