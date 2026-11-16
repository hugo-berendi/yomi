{pkgs, ...}: {
  # {{{ Local USB printing
  # CUPS listens on localhost:631 only (module defaults: no sharing, no firewall
  # opening). Its usb backend runs as root inside cupsd, so no udev rule or
  # group membership is needed. The admin web UI at http://localhost:631
  # authenticates against the wheel group (`SystemGroup` in the
  # NixOS-generated cupsd.conf), which the pilot is in.
  #
  # ipp-usb is deliberately not enabled. The nixpkgs module unconditionally
  # switches on avahi with publishing and SANE, and the Brother below is a
  # PPD-based printer anyway.
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
  # {{{ Network printers
  # Printers on the local network (driverless IPP Everywhere / AirPrint) show
  # up in the GTK print dialog and in system-config-printer through mDNS
  # discovery. Browsing only: publishing stays at its default of off, so the
  # laptop announces nothing. openFirewall (UDP 5353) is the module default
  # and is needed for the replies to come back.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # The cupsd module turns cups-browsed on whenever avahi is on. It is not
  # needed here: CUPS lists driverless DNS-SD printers in the print dialogs as
  # temporary queues on its own. cups-browsed is the daemon behind
  # CVE-2024-47176, and on a laptop that joins foreign networks it would
  # create queues for whatever printers those networks announce.
  services.printing.browsed.enable = false;
  # }}}
  # {{{ Printer setup GUI
  # Adding and configuring printers without the CUPS web UI. It talks to
  # cupsd over D-Bus; changes still ask for a wheel password through polkit.
  programs.system-config-printer.enable = true;
  # }}}
}
