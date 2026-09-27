# The main configuration is specified by home-manager
{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.yomi.machine.graphical;
  hyprlandConfig = "/home/${config.yomi.pilot.name}/.config/hypr/hyprland.lua";
  mkHyprlandPackage = hyprland:
    pkgs.symlinkJoin {
      name = "${hyprland.pname}-${hyprland.version}-lua-config";
      inherit (hyprland) pname version;
      paths = [hyprland];
      passthru =
        hyprland.passthru
        // {
          providedSessions = ["hyprland"];
          override = args: mkHyprlandPackage (hyprland.override args);
        };
      meta =
        hyprland.meta
        // {
          outputsToInstall = ["out"];
        };
      postBuild = ''
        rm -rf "$out/share/wayland-sessions"
        install -Dm644 \
          "${hyprland}/share/wayland-sessions/hyprland.desktop" \
          "$out/share/wayland-sessions/hyprland.desktop"
        # greetd gives the session tty1 as stdio; keep Hyprland's log off the
        # console, where it would show while the greeter hands over.
        sed -i \
          's|^Exec=.*|Exec=${lib.getExe' config.systemd.package "systemd-cat"} --identifier=hyprland ${lib.getExe' hyprland "start-hyprland"} -- --config ${hyprlandConfig}|' \
          "$out/share/wayland-sessions/hyprland.desktop"
      '';
    };
  hyprlandPackage = mkHyprlandPackage pkgs.hyprland;
in {
  config = lib.mkIf cfg {
    security.pam.services.hyprlock = {};

    programs.hyprland = {
      enable = true;
      package = hyprlandPackage;
    };

    environment.systemPackages = [config.programs.hyprland.package];
  };
}
