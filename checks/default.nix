# Flake checks: every host's toplevel plus the scenario tests under tests/.
{
  self,
  pkgs,
  myPkgs,
  dnsPackages,
}: let
  hosts = builtins.attrNames self.nixosConfigurations;
  # Scenario tests must be able to select network and unlock options
  # even when the recovery wizard's machine-specific overrides exist.
  inariTestConfiguration = self.nixosConfigurations.inari.extendModules {
    modules = [{disabledModules = [../hosts/nixos/inari/recovery-local.nix];}];
  };
in
  (builtins.listToAttrs (
    map (
      hostname: {
        name = "nixos-${hostname}";
        value = self.nixosConfigurations.${hostname}.config.system.build.toplevel;
      }
    )
    hosts
  ))
  // (builtins.listToAttrs (map (hostname: {
    name = "boot-space-${hostname}";
    value = import ../tests/boot-space.nix {
      inherit pkgs;
      configuration = self.nixosConfigurations.${hostname};
    };
  }) ["amaterasu" "inari"]))
  // {
    installer = import ../tests/installer.nix {inherit pkgs;};
    recover-tool = import ../tests/recover-tool.nix {inherit pkgs;};
    recover-disks = import ../tests/recover-disks.nix {
      inherit pkgs;
      package = myPkgs.yomi-recover;
    };
    recovery-options = import ../tests/recovery-options.nix {
      inherit pkgs;
      configuration = inariTestConfiguration;
    };
    calendar-sync = import ../tests/calendar-sync.nix {
      inherit pkgs;
      package = self.nixosConfigurations.inari.config.services.vdirsyncer.package;
    };
    persistence = import ../tests/persistence.nix {
      inherit pkgs;
      configurations = self.nixosConfigurations;
    };
    n8n-import = import ../tests/n8n-import.nix {
      inherit pkgs;
      configuration = self.nixosConfigurations.inari;
    };
    n8n-notifications = import ../tests/n8n-notifications.nix {inherit pkgs;};
    custom-options = import ../tests/options.nix {
      inherit pkgs;
      configurations = self.nixosConfigurations;
    };
    backup-monitoring = import ../tests/backup-monitoring.nix {
      inherit pkgs;
      rules = self.nixosConfigurations.inari.config.services.grafana.provision.alerting.rules.settings;
    };
    recovery = import ../tests/recovery.nix {
      inherit pkgs;
      config = self.nixosConfigurations.inari.config;
    };
    app-state-zfs = import ../tests/app-state-zfs.nix {
      inherit pkgs;
      config = self.nixosConfigurations.inari.config;
    };
    # Service unit tests live beside their modules and are exposed through
    # system.build so they build against the same python the service runs.
    diabetes = self.nixosConfigurations.inari.config.system.build.diabetes-tests;
    proton-mail-sorter = self.nixosConfigurations.inari.config.system.build.proton-mail-sorter-tests;
    dns-zones = dnsPackages.octodns-zones;
    dns-sync = dnsPackages.octodns-sync;
  }
