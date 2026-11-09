_: {
  # {{{ Local USB printing
  # CUPS listens on localhost:631 only (module defaults: no sharing, no firewall
  # opening, no network browsing). Its usb backend runs as root inside cupsd, so
  # no udev rule or group membership is needed. The admin web UI at
  # http://localhost:631 authenticates against the wheel group (`SystemGroup`
  # in the NixOS-generated cupsd.conf), which the pilot is in.
  #
  # ipp-usb is deliberately not enabled. The nixpkgs module unconditionally
  # switches on avahi with publishing and SANE, which is network discovery
  # nobody asked for. Add it, restricted, only once a driverless printer
  # turns out to need it.
  services.printing.enable = true;

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
