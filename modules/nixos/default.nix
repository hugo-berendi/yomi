# (https://nixos.wiki/wiki/Module).
{
  dns = {imports = [../../dns/implementation/nixos-module.nix ../../dns/implementation/nixos-module-assertions.nix];};
  restic = import ./restic.nix;
  postgres = import ./postgres.nix;
  meilisearch = import ./meilisearch.nix;
  acme = import ./acme.nix;
  machine = import ./machine.nix;
  hermes-dispatcher = import ./hermes-dispatcher;
  network-exposure = import ./network-exposure.nix;
  persistence = import ./persistence.nix;
  web = import ./web.nix;
  nginx = import ./nginx.nix;
  filesystems = import ./filesystems.nix;
  forgejo-ci-worker = import ./forgejo-ci-worker.nix;
  endpoint-checks = import ./endpoint-checks.nix;
  expose = import ./expose;
  iocaine = import ./iocaine.nix;
  playit = import ./playit.nix;
  ports = import ./ports.nix;
  pounce = import ./pounce.nix;
  protonvpn = import ./protonvpn.nix;
  steam-game-server = import ./steam-game-server.nix;
  vrising = import ./vrising;
  windrose = import ./windrose.nix;
  wireless = import ./wireless;
}
