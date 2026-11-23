# Files dropped into a Nextcloud user's 'Paperless' folder move to the
# paperless consume directory every two minutes.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.nextcloud;
  occ = lib.getExe cfg.occ;
  # Files dropped here in the web UI or the sync client are handed to paperless.
  paperlessInbox = "Paperless";
  consumeDir = config.services.paperless.consumptionDir;

  # Moving, not copying: paperless deletes nothing in Nextcloud, and a copy
  # would leave every scan in both places. nextcloud owns the files, so the
  # job runs as nextcloud and writes into the paperless consume directory
  # through the paperless group; the follow-up scan drops the now-missing rows
  # from Nextcloud's file cache.
  paperlessHandoff = pkgs.writeShellApplication {
    name = "nextcloud-to-paperless";
    runtimeInputs = [pkgs.coreutils pkgs.findutils];
    text = ''
      shopt -s nullglob
      for inbox in ${cfg.datadir}/data/*/files/${paperlessInbox}; do
        user=$(basename "$(dirname "$(dirname "$inbox")")")
        moved=0
        for f in "$inbox"/*; do
          [ -f "$f" ] || continue
          # Skip files a sync client is still uploading.
          [ -n "$(find "$f" -mmin -1 -print -quit)" ] && continue
          mv -n -- "$f" "${consumeDir}/nextcloud-$user-$(basename "$f")" && moved=1
        done
        [ "$moved" = 1 ] && { ${occ} files:scan --path="$user/files/${paperlessInbox}" --quiet || true; }
      done
      exit 0
    '';
  };
in {
  users.users.nextcloud.extraGroups = ["paperless"];
  # The consume directory is private to paperless by default; the group needs
  # write access so the hand-off job can drop files in.
  systemd.tmpfiles.settings."10-nextcloud-paperless".${consumeDir}.d = {
    mode = "0770";
    user = config.services.paperless.user;
    group = "paperless";
  };

  systemd.services.nextcloud-to-paperless = {
    description = "Move Nextcloud '${paperlessInbox}' folder contents into paperless";
    after = ["nextcloud-setup.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      ExecStart = lib.getExe paperlessHandoff;
    };
    path = [pkgs.coreutils pkgs.findutils];
  };
  systemd.timers.nextcloud-to-paperless = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "2min";
    };
  };
}
