{
  lib,
  pkgs,
  ...
}: let
  # pamu2fcfg output: the pilot's username, a key handle and a public key.
  # None of it is secret -- it identifies the credential, it cannot sign --
  # so it lives here rather than in ~/.config/Yubico, where the rollback
  # would wipe it on every boot and quietly bring the passwords back.
  #
  # builtins.path so the file gets its own store path; a bare ./u2f_keys
  # lands in the flake source, whose hash moves on every commit and would
  # rewrite every /etc/pam.d file on every switch.
  registered = builtins.pathExists ./u2f_keys;
  authFile = builtins.path {
    path = ./u2f_keys;
    name = "u2f_keys";
  };
  origin = "pam://amaterasu";
in {
  # {{{ Touch instead of a password
  # The key has to be inserted and touched; no PIN. A process running as the
  # pilot therefore cannot sudo on its own while the key is plugged in -- it
  # still needs a finger on the key. `sufficient` keeps the password as the
  # fallback, so a lost key does not lock anyone out.
  #
  # Only enabled once the credential exists. Before that pam_u2f would fail
  # every attempt and fall through to the password, which works but prints
  # an error on each sudo.
  security.pam.u2f = lib.mkIf registered {
    enable = true;
    control = "sufficient";
    settings = {
      authfile = authFile;
      inherit origin;
      appid = origin;
      cue = true; # "Please touch the device." -- otherwise sudo just hangs
    };
  };

  # pam_u2f is added to every PAM service by default. sshd here is key-only
  # (password and keyboard-interactive both off), so its auth stack is never
  # reached today -- but if that ever changed, a remote login would succeed
  # on a touch of the key sitting in this laptop.
  security.pam.services.sshd.u2fAuth = false;

  warnings = lib.optional (!registered) ''
    hosts/nixos/amaterasu/u2f_keys is missing, so the YubiKey cannot
    authenticate sudo, login or the lock screen yet. Register it with:

      nix shell nixpkgs#pam_u2f -c pamu2fcfg -o ${origin} -i ${origin} > hosts/nixos/amaterasu/u2f_keys
      git add hosts/nixos/amaterasu/u2f_keys
  '';
  # }}}

  # {{{ Lock when the key leaves
  # hypridle skips its idle lock while the key is inserted
  # (home/features/wayland/hyprland/hypridle.nix), so taking the key with
  # you is how the session locks. loginctl lock-sessions sends the Lock
  # signal hypridle already answers with hyprlock.
  #
  # Matched on the USB device itself, not its interfaces, so one removal is
  # one lock. PRODUCT is vendor/product/bcd in unpadded hex; 1050 is Yubico.
  services.udev.extraRules = ''
    ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="1050/*", RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"
  '';
  # }}}
}
