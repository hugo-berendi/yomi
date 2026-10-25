{
  config,
  lib,
  ...
}: let
  graphical = config.yomi.machine.graphical;
in {
  # {{{ 1Password
  # 1Password holds the pilot's own passwords and secrets. sops stays the
  # source for what services need at boot, which must work offline.
  #
  # The CLI everywhere. The NixOS module installs `op` setgid to the
  # onepassword-cli group, which is how the desktop app recognises it: on
  # amaterasu `op` then unlocks through the app instead of a separate login.
  # On inari and wsl it signs in on its own (`op signin`).
  programs._1password.enable = true;

  # The app only where there is a desktop. polkit lets it unlock with the
  # pilot's system authentication.
  programs._1password-gui = lib.mkIf graphical {
    enable = true;
    polkitPolicyOwners = [config.yomi.pilot.name];
  };

  # The browser extension only talks to browsers the app knows. Helium is a
  # Chromium build it does not ship in its list; the entry is the process
  # name, from pkgs/helium.nix. The file must be root-owned and 0755.
  environment.etc."1password/custom_allowed_browsers" = lib.mkIf graphical {
    text = "helium\n";
    mode = "0755";
  };
  # }}}
}
