{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  pilot = config.yomi.pilot.name;
  home = config.users.users.${pilot}.home;
  package = import ../../../../pkgs/t3code-tools.nix {inherit pkgs inputs;};
  startUserManager = pkgs.writeShellScript "t3code-repair-user-manager" ''
    uid=$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg pilot})
    exec ${pkgs.systemd}/bin/systemctl start "user@$uid.service"
  '';
  launcher = pkgs.writeShellScript "t3code-package-repair" ''
    export PATH=${lib.makeBinPath [pkgs.git pkgs.openssh pkgs.python313 package]}:/run/current-system/sw/bin
    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent"
    ${pkgs.systemd}/bin/systemctl --user start ssh-agent.service t3code-web.service
    exec ${pkgs.python313}/bin/python3 ${./t3code-repair/launch.py} \
      --repository hugo-berendi/yomi \
      --remote forgejo@ssh.git.hugo-berendi.de:hugo-berendi/yomi.git \
      --t3code-remote forgejo@ssh.git.hugo-berendi.de:hugo-berendi/t3code-nix.git \
      --forgejo https://git.hugo-berendi.de \
      --forgejo-api http://127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT} \
      --state-dir ${home}/.local/state/t3code-package-repair \
      --t3-base-dir ${home}/.t3
  '';
in {
  # Only the native Actions runner may submit requests. Authentication stays
  # with the pilot's T3 and SSH clients; no tokens enter job logs or prompts.
  systemd.sockets.t3code-package-repair = {
    wantedBy = ["sockets.target"];
    socketConfig = {
      ListenStream = "/run/t3code-package-repair.sock";
      Accept = true;
      SocketUser = "gitea-runner";
      SocketMode = "0600";
      # The capability probe may still be exiting when its repair request arrives.
      # Launches themselves remain serialized by each repository's lock.
      MaxConnections = 2;
    };
  };
  systemd.services."t3code-package-repair@" = {
    requires = ["systemd-user-sessions.service"];
    after = ["systemd-user-sessions.service" "home-manager-${pilot}.service"];
    serviceConfig = {
      User = pilot;
      # NixOS allocates this user's UID at activation. Resolve it at runtime,
      # wait for the user manager, then start its SSH agent as the pilot.
      ExecStartPre = "+${startUserManager}";
      ExecStart = launcher;
      StandardInput = "socket";
      StandardOutput = "socket";
      StandardError = "journal";
      NoNewPrivileges = true;
      PrivateTmp = true;
      UMask = "0077";
      TimeoutStartSec = "5min";
    };
  };
  home-manager.users.${pilot}.yomi.persistence.at.state.apps.t3code-package-repair.directories = [
    "${home}/.local/state/t3code-package-repair"
  ];
}
