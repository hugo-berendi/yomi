{pkgs, ...}: {
  # Add this URL as a sops secret once an external monitor is chosen. Hosting
  # the receiver on inari would hide the very outages this timer should detect.
  systemd.services.external-heartbeat = {
    description = "Send inari's heartbeat to an external monitor";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    unitConfig.ConditionPathExists = "/run/secrets/inari_heartbeat_url";
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      LoadCredential = "url:/run/secrets/inari_heartbeat_url";
      TimeoutStartSec = "45s";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
    script = ''
      set -euo pipefail
      # Pass the token-bearing URL on stdin, keeping it out of the process list.
      url=$(cat "$CREDENTIALS_DIRECTORY/url")
      case "$url" in
        https://*) ;;
        *) echo "Heartbeat URL must use HTTPS" >&2; exit 1 ;;
      esac
      printf 'url = "%s"\n' "$url" | ${pkgs.curl}/bin/curl --config - \
        --proto '=https' --fail --silent --show-error --output /dev/null \
        --connect-timeout 10 --max-time 30
    '';
  };
  systemd.timers.external-heartbeat = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2m";
      OnCalendar = "*-*-* *:0/5:00";
      RandomizedDelaySec = "30s";
    };
  };
}
