# Settings every host shares, including a VPS that must not carry the home
# fleet's desktop, user and monitoring collections. Home hosts import a role
# profile instead (./desktop.nix, ./server.nix, ./recovery.nix, ./wsl.nix),
# which brings this file and ./fleet.nix.
{
  config,
  inputs,
  lib,
  outputs,
  ...
}: let
  inventory = import ./inventory.nix;

  # {{{ Imports
  imports = [
    # Framework modules whose options the yomi modules below set, even when the
    # feature that uses them is switched off.
    inputs.disko.nixosModules.default
    inputs.sops-nix.nixosModules.sops
    inputs.playit-nixos-module.nixosModules.default

    ../common/nixpkgs.nix

    ../hosts/nixos/common/cli/fish.nix
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
  # Every fleet host's address comes from ./inventory.nix instead of evaluating
  # each sibling configuration for its yomi.dns.records.
  networking.extraHosts = lib.pipe inventory [
    (lib.filterAttrs (_: host: host ? ipv4))
    (lib.mapAttrsToList (name: host: "${host.ipv4} ${name}"))
    (lib.sort builtins.lessThan)
    (lib.concatStringsSep "\n")
  ];

  # Other hosts used to read this host's own A records back; they now read the
  # inventory, so a record that disagrees with it would go stale everywhere
  # else without a word.
  assertions = let
    hostname = config.networking.hostName;
    fleetRecords =
      lib.filter (record: record.type == "A" && inventory ? ${record.at})
      config.yomi.dns.records;
    wrong = lib.filter (record: (inventory.${record.at}.ipv4 or null) != record.value) fleetRecords;
    expected = inventory.${hostname}.ipv4 or null;
  in [
    {
      assertion = wrong == [];
      message = ''
        yomi.dns.records has A records for fleet hosts that disagree with
        profiles/inventory.nix: ${lib.concatMapStringsSep ", " (r: "${r.at} -> ${r.value}") wrong}.
        Every other host's /etc/hosts reads the inventory; update it alongside.
      '';
    }
    {
      assertion = expected == null || lib.any (record: record.at == hostname) fleetRecords;
      message = ''
        profiles/inventory.nix gives ${hostname} the address ${toString expected},
        but ${hostname} declares no A record for itself in yomi.dns.records.
      '';
    }
  ];

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
