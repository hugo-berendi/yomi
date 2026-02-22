{
  config,
  lib,
  pkgs,
  ...
}: let
  stylixScheme = config.lib.stylix.colors.scheme;
  stylixMode = config.stylix.polarity;

  caelestiaScheme =
    if lib.hasPrefix "rose-pine" stylixScheme
    then "rosepine"
    else if lib.hasPrefix "catppuccin" stylixScheme
    then "catppuccin"
    else if lib.hasPrefix "gruvbox" stylixScheme
    then "gruvbox"
    else null;

  caelestiaFlavour =
    if stylixScheme == "rose-pine"
    then "main"
    else if lib.hasPrefix "rose-pine-" stylixScheme
    then lib.removePrefix "rose-pine-" stylixScheme
    else if lib.hasPrefix "catppuccin-" stylixScheme
    then lib.removePrefix "catppuccin-" stylixScheme
    else if lib.hasPrefix "gruvbox-light" stylixScheme
    then "light"
    else if lib.hasPrefix "gruvbox-dark" stylixScheme
    then "dark"
    else null;

  caelestiaCliBin = "${config.programs.caelestia.cli.package}/bin/caelestia";

  caelestiaStylixSyncScript = pkgs.writeShellScript "caelestia-stylix-sync" ''
    set -eu

    ${pkgs.coreutils}/bin/sleep 2

    if [ -x "${caelestiaCliBin}" ]; then
      "${caelestiaCliBin}" wallpaper -f "${toString config.stylix.image}" --no-smart >/dev/null 2>&1 || true
      ${lib.optionalString (caelestiaScheme != null && caelestiaFlavour != null) ''
      "${caelestiaCliBin}" scheme set -n "${caelestiaScheme}" -f "${caelestiaFlavour}" -m "${stylixMode}" >/dev/null 2>&1 || true
    ''}
    fi
  '';
in {
  programs.caelestia = {
    enable = true;
    cli.enable = true;
    systemd.enable = true;

    settings = {
      appearance = {
        font = {
          family = {
            sans = config.stylix.fonts.sansSerif.name;
            mono = config.stylix.fonts.monospace.name;
            clock = config.stylix.fonts.serif.name;
          };
        };

        transparency = {
          enabled = true;
          base = config.stylix.opacity.applications;
        };
      };

      paths = {
        wallpaperDir = "~/projects/yomi/common/themes/wallpapers";
      };

      services = {
        smartScheme = false;
      };

      launcher = {
        enableDangerousActions = false;
      };
    };
  };

  systemd.user.services.caelestia-stylix-sync = {
    Unit = {
      Description = "Sync Caelestia theme from Stylix";
      After = [
        "graphical-session.target"
        "caelestia.service"
      ];
      Wants = ["caelestia.service"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${caelestiaStylixSyncScript}";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
