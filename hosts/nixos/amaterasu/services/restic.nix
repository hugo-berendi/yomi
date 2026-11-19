{
  config,
  outputs,
  ...
}: let
  inherit (outputs.nixosConfigurations.inari.config.yomi.inari) lanIPv4;
in {
  # Backups of /persist/data and /persist/state, pushed over sftp to a
  # dedicated, chrooted account on inari (see hosts/nixos/inari/services/restic/default.nix).
  #
  # Unlike inari's own local set, this is real redundancy: a different disk in
  # a different box, not another dataset on the same one. It is also only
  # reachable while amaterasu is on the home network -- restic's timer just
  # retries on the next run, so a laptop away for a while backs up late
  # rather than not at all. Nothing here goes off-site: amaterasu keeps no
  # data that only exists on this laptop, everything else is in git already.
  sops.secrets.amaterasu_restic_ssh_key.sopsFile = ../secrets.yaml;

  # The backup must use the LAN without relying on MagicDNS. Keep checking
  # Inari's pinned host key even when connecting directly to its IPv4 address.
  programs.ssh.extraConfig = ''
    Host inari-restic
      HostName ${lanIPv4}
      HostKeyAlias inari
      IdentityFile ${config.sops.secrets.amaterasu_restic_ssh_key.path}
  '';

  yomi.restic = {
    enable = true;
    repository = "sftp:restic-amaterasu@inari-restic:/data";
  };
}
