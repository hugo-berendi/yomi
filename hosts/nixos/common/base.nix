# Settings every host shares, including a VPS that must not carry the home
# fleet's desktop, user and monitoring collections. Hosts that want those add
# ./profiles/fleet.nix (through ./default.nix) on top of this.
{
  inputs,
  lib,
  outputs,
  ...
}: let
  # {{{ Imports
  imports = [
    # Framework modules whose options the yomi modules below set, even when the
    # feature that uses them is switched off.
    inputs.disko.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    inputs.playit-nixos-module.nixosModules.default

    ../../../common/nixpkgs.nix

    ./cli/fish.nix
    ./nix.nix
    # Also brings the impermanence module, which yomi.persistence writes to.
    ./persistence.nix

    ./services/memory.nix
    ./services/openssh.nix
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
