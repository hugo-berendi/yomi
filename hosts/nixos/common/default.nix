{
  inputs,
  lib,
  outputs,
  config,
  ...
}: let
  # {{{ Imports
  imports = [
    inputs.disko.nixosModules.default
    inputs.stylix.nixosModules.stylix
    inputs.sops-nix.nixosModules.sops
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.authentik-nix.nixosModules.default
    inputs.nixarr.nixosModules.default

    ../../../dns/implementation/nixos-module.nix
    ../../../dns/implementation/nixos-module-assertions.nix
    ../../../common

    ./base
    ./cli
    ./nix.nix
    ./desktop
    ./wireless
    ./persistence.nix
    ./users/pilot.nix

    # services
    ./services/acme.nix
    ./services/greetd.nix
    ./services/nginx.nix
    ./services/oci.nix
    ./services/openssh.nix
    # ./services/restic
    ./services/syncthing.nix
    ./services/tailscale.nix
    ./services/postgres.nix
  ];
  # }}}
in {
  # Import all modules defined in modules/nixos
  imports = builtins.attrValues outputs.nixosModules ++ imports;

  # Tell sops-nix to use the host keys for decrypting secrets
  sops.age.sshKeyPaths = ["/persist/state/etc/ssh/ssh_host_ed25519_key"];

  # {{{ ad-hoc options
  # Use DHCP/NetworkManager-provided DNS by default; AdGuardHome sets this on its host.

  # /etc/hosts
  networking.extraHosts = let
    hosts = hostnames:
      lib.concatStringsSep "\n" (
        lib.flatten (
          lib.mapAttrsToList
          (ip: recordsList: map (record: "${ip} ${record.at}") recordsList)
          (
            lib.groupBy
            (record: record.value)
            (
              lib.filter
              (record: record.type == "A" && lib.elem record.at hostnames)
              (lib.flatten (lib.forEach
                hostnames
                (hostname:
                  inputs.self.nixosConfigurations.${hostname}.config.yomi.dns.records)))
            )
          )
        )
      );
  in
    hosts ["inari" "amaterasu"];

  # Customize tty colors
  stylix.targets.console.enable = lib.mkIf config.yomi.machine.interactible true;

  # Reduce the amount of storage spent for logs
  services.journald.extraConfig = lib.mkDefault ''
    SystemMaxUse=256M
  '';

  # Boot using systemd
  boot.initrd.systemd.enable = true;
  # }}}
  # {{{ Disable sudo default lecture
  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';
  # }}}

  # Root domain used throughout my config
  yomi.dns.domain = "hugo-berendi.de";

  # locales
  i18n.defaultLocale = "de_DE.UTF-8";
  time.timeZone = "Europe/Berlin";
}
