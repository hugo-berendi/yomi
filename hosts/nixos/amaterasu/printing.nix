{pkgs, ...}: {
  # {{{ Local USB printing
  # CUPS listens on localhost:631 only (module defaults: no sharing, no firewall
  # opening, no network browsing). Its usb backend runs as root inside cupsd, so
  # no udev rule or group membership is needed. The admin web UI at
  # http://localhost:631 authenticates against the wheel group (`SystemGroup`
  # in the NixOS-generated cupsd.conf), which the pilot is in.
  #
  # ipp-usb is deliberately not enabled. The nixpkgs module unconditionally
  # switches on avahi with publishing and SANE, which is network discovery
  # nobody asked for, and the Brother below is a PPD-based printer anyway.
  services.printing.enable = true;

  # Brother MFC-1910W. brlaser's PPD list names "MFC-1910W series" (checked in
  # share/cups/drv/brlaser.drv of the pinned package). Printing only: the
  # scanner and fax parts are out of scope.
  services.printing.drivers = [pkgs.brlaser];

  # Root is rolled back at boot; printers.conf and the PPD files live in
  # /var/lib/cups, so a configured printer would vanish at the next reboot.
  # The spool and cache stay ephemeral on purpose.
  yomi.persistence.at.state.apps.cups.directories = [
    {
      directory = "/var/lib/cups";
      mode = "0755";
    }
  ];
  # }}}
}
