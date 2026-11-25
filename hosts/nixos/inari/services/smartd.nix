# smartd watches the drives' SMART data and mails root about a failing health
# check, new errors in a drive's log and pending or offline-uncorrectable
# sectors. Grafana's disk alert (prometheus smartctl exporter) only sees the
# overall health verdict, so smartd is the early warning.
#
# Scrutiny's collector used to switch this on; it stays now that Scrutiny is
# gone, with smartd's default 30-minute interval instead of Scrutiny's 10.
# Its log says it cannot open the USB disks of raid5pool ("open() of ATA
# device failed: No such device"), so it may watch the NVMe only.
_: {
  services.smartd.enable = true;
}
