# A graphical workstation (amaterasu): the shared fleet settings plus the
# desktop session, its greeter, Wi-Fi and the local restic sets.
{
  imports = [
    ../base.nix
    ./fleet.nix

    ../desktop
    ../services/greetd
    ../services/restic.nix
  ];

  yomi.wireless.sopsFile = ../secrets.yaml;
}
