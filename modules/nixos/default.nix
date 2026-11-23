# (https://nixos.wiki/wiki/Module).
{
  dns = {imports = [../../dns/implementation/nixos-module.nix ../../dns/implementation/nixos-module-assertions.nix];};
  restic = ./restic.nix;
  postgres = ./postgres.nix;
  meilisearch = ./meilisearch.nix;
  acme = ./acme.nix;
  machine = ./machine.nix;
  network-exposure = ./network-exposure.nix;
  persistence = ./persistence.nix;
  web = ./web.nix;
  nginx = ./nginx.nix;
  filesystems = ./filesystems.nix;
  forgejo-ci-worker = ./forgejo-ci-worker.nix;
  endpoint-checks = ./endpoint-checks.nix;
  expose = ./expose;
  iocaine = ./iocaine.nix;
  playit = ./playit.nix;
  ports = ./ports.nix;
  pounce = ./pounce.nix;
  protonvpn = ./protonvpn.nix;
  steam-game-server = ./steam-game-server;
  vrising = ./vrising;
  windrose = ./windrose.nix;
  wireless = ./wireless;
}
