{
  config,
  lib,
  pkgs,
  ...
}: let
  # builtins.path rather than a bare ./ reference: a plain path resolves into
  # the flake source store path, whose hash changes on every commit, so the
  # unit would be "changed" and restart on every switch.
  sorter = builtins.path {
    path = ./n8n/backfill.py;
    name = "mail-sorter.py";
  };

  mailbox = "personal@hugo-berendi.de";

  # The secret ships as this literal so a fresh deploy cannot break activation
  # by referencing a key that is not in secrets.yaml yet. Checking for it here
  # matters more than it looks: without it the timer would fire every two
  # hours against Migadu with a wrong password, and Migadu answers repeated
  # failures with "temporary authentication failure", which is how an account
  # earns a rate limit.
  placeholder = "REPLACE_ME";

  run = pkgs.writeShellScript "mail-sorter-run" ''
    set -euo pipefail

    password=$(cat "$CREDENTIALS_DIRECTORY/imap-password")
    if [ "$password" = "${placeholder}" ]; then
      echo "mail-sorter: imap_personal_password is still the placeholder."
      echo "Set it with:  sops hosts/nixos/inari/secrets.yaml"
      echo "Skipping, so repeated failed logins cannot get the mailbox rate limited."
      exit 0
    fi

    export IMAP_PASSWORD="$password"
    exec ${pkgs.python3}/bin/python3 ${sorter} \
      --user ${lib.escapeShellArg mailbox} \
      --state "$STATE_DIRECTORY/state.json" \
      --apply
  '';
in {
  # {{{ Secret
  sops.secrets.imap_personal_password.sopsFile = ../secrets.yaml;
  # }}}

  # {{{ Service
  # Classifies whatever is new in the inbox and files it into folders. The n8n
  # organizer cannot do this -- its IMAP node is a trigger with no move
  # operation -- so the workflow keeps the daily digest and this keeps the
  # mailbox tidy. Both read the same taxonomy, which is duplicated between
  # backfill.py and the workflow's Code node because Code nodes cannot import.
  systemd.services.mail-sorter = {
    description = "Classify inbox mail and file it into folders";
    after = ["network-online.target" "llama-cpp-classifier.service"];
    wants = ["network-online.target" "llama-cpp-classifier.service"];

    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      StateDirectory = "mail-sorter";

      # LoadCredential rather than EnvironmentFile: systemd reads the sops
      # secret as root before the DynamicUser sandbox applies, so the unit
      # never needs read access to /run/secrets itself. EnvironmentFile would
      # also need the file to be KEY=VALUE, which a raw password is not.
      LoadCredential = ["imap-password:${config.sops.secrets.imap_personal_password.path}"];

      ExecStart = run;
    };
  };
  # }}}

  # {{{ Timer
  systemd.timers.mail-sorter = {
    description = "Periodic inbox sorting";
    wantedBy = ["timers.target"];
    timerConfig = {
      # Every ten minutes rather than every two hours: each unseen sender
      # still costs about fifteen seconds of CPU on a box with no GPU, but a
      # run that finds nothing new exits in under a second, so the tighter
      # interval only costs anything when there is mail to file.
      OnCalendar = "*-*-* *:0/10:00";
      RandomizedDelaySec = "30s";
      Persistent = true;
    };
  };
  # }}}

  # IMAP and the classifier need IP sockets; local credentials use Unix sockets.
  systemd.services.mail-sorter.serviceConfig = {
    CapabilityBoundingSet = [""];
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateMounts = true;
    PrivateTmp = true;
    PrivateUsers = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    RestrictNamespaces = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
  };
}
