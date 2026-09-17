{
  # Backups of /persist/data and /persist/state. The repository lives on the
  # redundant raid5pool rather than on the NVMe the data itself sits on, so it
  # survives losing zroot.
  #
  # It does not survive losing raid5pool, and that pool is a raidz1 whose third
  # member is a USB-attached disk. Everything irreplaceable that lives only on
  # that pool -- the immich library above all -- therefore also goes off-site.
  yomi.restic = {
    enable = true;
    repository = "/raid5pool/backups/restic";

    # {{{ Off-site
    # Requires b2_bucket, b2_account_id and b2_account_key in
    # hosts/nixos/inari/secrets.yaml; activation fails without them.
    offsite = {
      enable = true;
      sopsFile = ../secrets.yaml;

      # Roughly 96 GiB as of 2026-09. Everything else on raid5pool is
      # reacquirable: media/movies, media/tv and the 222 GiB of media/comics
      # can all be fetched again, and /raid5pool/cloud holds 1.7 MiB because
      # owncloud is effectively unused.
      paths = [
        "/raid5pool/media/photos" # immich library, 83 GiB, the whole point
        "/raid5pool/media/documents" # paperless documents
        "/raid5pool/data" # paperless index, navidrome
        "/persist/data" # calendars, contacts, game server worlds

        # Without the dumps, an off-site restore returns immich's photos and
        # paperless' documents as loose files with nothing describing them --
        # no albums, no users, no tags. Compressed dumps of every database,
        # written by services.postgresqlBackup half an hour before this runs.
        "/persist/state/var/backup/postgresql"
      ];

      exclude = [
        # immich regenerates all of these from the originals
        "/raid5pool/media/photos/thumbs"
        "/raid5pool/media/photos/encoded-video"
      ];
    };
    # }}}
  };

  # The restic repository used to sit directly in the raid5pool root dataset,
  # which sanoid snapshots hourly. Every pack file restic pruned stayed pinned
  # by those snapshots, so the repository could only ever grow. It now has its
  # own dataset with snapshots turned off.
  services.sanoid.datasets."raid5pool/backups" = {
    autosnap = false;
    autoprune = false;
  };

  systemd.tmpfiles.rules = ["d /raid5pool/backups/restic 0700 root root -"];
}
