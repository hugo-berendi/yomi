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

    inputs.nixarr.nixosModules.default
    inputs.playit-nixos-module.nixosModules.default

    ../../../common

    ./cli/fish.nix
    ./cli/1password.nix
    ./nix.nix
    ./desktop
    ./persistence.nix
    ./users/pilot.nix

    # services
    ./services/beszel-agent.nix
    ./services/greetd
    ./services/memory.nix
    ./services/oci.nix
    ./services/openssh.nix
    ./services/syncthing.nix
    ./services/restic.nix
  ];
  # }}}
in {
  # Import all modules defined in modules/nixos
  imports = builtins.attrValues outputs.nixosModules ++ imports;

  yomi.wireless.sopsFile = ./secrets.yaml;

  # Tell sops-nix to use the host keys for decrypting secrets
  sops.age.sshKeyPaths = ["/persist/state/etc/ssh/ssh_host_ed25519_key"];

  yomi.acme = {
    sopsFile = ./secrets.yaml;
    email = "acme@hugo-berendi.de";
  };

  # {{{ ad-hoc options
  # Use DHCP/NetworkManager-provided DNS by default; AdGuardHome sets this on its host.

  # /etc/hosts
  networking.extraHosts = let
    allHostnames = lib.attrNames inputs.self.nixosConfigurations;
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
    hosts allHostnames;

  console.keyMap = lib.mkForce "de";

  # Customize tty colors
  stylix.targets.console.enable = lib.mkIf config.yomi.machine.interactible true;

  # Reduce the amount of storage spent for logs
  services.journald.extraConfig = lib.mkDefault ''
    SystemMaxUse=256M
  '';

  # Boot using systemd
  boot.initrd.systemd.enable = true;
  # The deployed 512 MiB ESPs cannot hold ten distinct kernel/initrd pairs.
  # Keep two rollback entries; boot-space flake checks reserve update headroom.
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 3;
  # }}}
  # {{{ Sudo configuration
  security.sudo = {
    wheelNeedsPassword = true;
    extraConfig = ''
      Defaults lecture = never
    '';
  };
  # }}}

  # Root domain used throughout my config
  yomi.dns.domain = "hugo-berendi.de";

  # locales
  i18n.defaultLocale = "de_DE.UTF-8";
  time.timeZone = "Europe/Berlin";
}
