{
  # Backups of /persist/data and /persist/state. The repository lives on the
  # redundant raid5pool rather than on the NVMe the data itself sits on, so it
  # survives losing zroot. It is not off-site, which is still missing.
  yomi.restic = {
    enable = true;
    repository = "/raid5pool/backups/restic";
  };

  systemd.tmpfiles.rules = ["d /raid5pool/backups/restic 0700 root root -"];
}
