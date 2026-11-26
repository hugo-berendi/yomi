# A graphical workstation (amaterasu): the shared fleet settings plus the
# desktop session, its greeter, Wi-Fi and the local restic sets.
{config, ...}: {
  imports = [
    ./base.nix
    ./fleet.nix

    ./home-manager.nix
    ../home/features/desktop/system.nix
    ./services/greetd
    ./services/restic.nix
  ];

  yomi.wireless.sopsFile = ./secrets.yaml;

  # Hyprland and, through it, the wayland and desktop applications.
  home-manager.users.${config.yomi.pilot.name}.imports = [../home/features/wayland/hyprland];
}
