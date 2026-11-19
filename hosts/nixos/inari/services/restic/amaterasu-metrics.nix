{
  config,
  lib,
  pkgs,
  ...
}: let
  repository = "/raid5pool/backups/restic-amaterasu/data";
  metricsDirectory = "/var/lib/restic-metrics";
  collect = pkgs.writeShellApplication {
    name = "amaterasu-backup-metrics";
    runtimeInputs = [pkgs.coreutils pkgs.jq pkgs.restic];
    text = ''
      output="''${1:-${metricsDirectory}/amaterasu.prom}"
      staging=$(mktemp "$output.XXXXXX")
      trap 'rm -f "$staging"' EXIT

      printf '%s\n' \
        '# HELP yomi_restic_last_success_timestamp_seconds Unix timestamp of the last successful restic job.' \
        '# TYPE yomi_restic_last_success_timestamp_seconds gauge' > "$staging"
      for backup in data state; do
        # The writer lives on the laptop. Listing snapshots needs no lock
        # and does not modify the repository received over SFTP.
        snapshot=$(restic --no-lock --repo "${repository}/$backup" \
          --password-file "${config.sops.secrets.backup_password.path}" \
          snapshots --host amaterasu --path "/persist/$backup" --latest 1 --json |
          jq -er '.[0].time')
        timestamp=$(date -d "$snapshot" +%s)
        printf 'yomi_restic_last_success_timestamp_seconds{host="amaterasu",backup="%s"} %s\n' \
          "$backup" "$timestamp" >> "$staging"
      done

      chmod 0644 "$staging"
      mv -f "$staging" "$output"
    '';
  };
in {
  systemd.services.amaterasu-backup-metrics = {
    description = "Publish the latest laptop snapshots received by Inari";
    unitConfig.RequiresMountsFor = [repository metricsDirectory];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe collect;
      PrivateNetwork = true;
      ProtectSystem = "strict";
      ReadWritePaths = [metricsDirectory];
    };
  };
  systemd.timers.amaterasu-backup-metrics = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
