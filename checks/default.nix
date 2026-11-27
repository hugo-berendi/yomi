# Flake checks: every host's toplevel plus the scenario tests under tests/.
{
  self,
  pkgs,
  myPkgs,
  dnsPackages,
  optionsDoc,
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
    firewall-reload = import ../tests/firewall-reload.nix {
      inherit pkgs;
      config = self.nixosConfigurations.inari.config;
    };
    web-endpoints = import ../tests/web-endpoints.nix {
      inherit pkgs;
      configuration = self.nixosConfigurations.inari;
    };
    deployment-health = pkgs.runCommand "deployment-health-tests" {nativeBuildInputs = [pkgs.python3];} ''
      mkdir -p tests scripts/ops
      cp ${../tests/test_deployment_health.py} tests/test_deployment_health.py
      cp ${../scripts/ops/deployment-health.py} scripts/ops/deployment-health.py
      python3 -m unittest discover -s tests -p test_deployment_health.py
      touch "$out"
    '';
    release-upgrade =
      pkgs.runCommand "release-upgrade-tests" {
        nativeBuildInputs = [pkgs.python3 pkgs.openssh pkgs.bash];
      } ''
        mkdir -p tests scripts/ops pkgs/yomi-recover
        cp ${../tests/test_release_upgrade.py} tests/test_release_upgrade.py
        cp ${../scripts/ops/release-upgrade.py} scripts/ops/release-upgrade.py
        cp ${../pkgs/yomi-recover/recover.py} pkgs/yomi-recover/recover.py
        python3 -m unittest discover -s tests -p test_release_upgrade.py
        touch "$out"
      '';
    # Unit tests that load their script from the repository by path.
    python-units = pkgs.runCommand "python-unit-tests" {nativeBuildInputs = [pkgs.python3 pkgs.gitMinimal];} ''
      cd ${self}
      PYTHONDONTWRITEBYTECODE=1 python3 -m unittest \
        tests.test_package_repair_request \
        tests.test_t3code_package_repair \
        tests.test_t3code_test_workspace \
        tests.test_t3code_vm_bootstrap \
        tests.test_t3code_vm_provision
      touch "$out"
    '';
    expose = import ../tests/expose.nix {inherit pkgs self;};
    expose-backup =
      pkgs.runCommand "expose-backup-tests" {
        nativeBuildInputs = [pkgs.python3];
        EXPOSE_BACKUP_HELPER = ../modules/nixos/expose/backup.py;
      } ''
        python ${../tests/expose-backup.py}
        touch "$out"
      '';
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
    zfs-capacity = pkgs.runCommand "zfs-capacity-tests" {nativeBuildInputs = [pkgs.python3];} ''
      mkdir -p tests hosts/nixos/inari/services/zfs
      cp ${../tests/test_zfs_capacity.py} tests/test_zfs_capacity.py
      cp ${../hosts/nixos/inari/services/zfs/capacity.py} hosts/nixos/inari/services/zfs/capacity.py
      python3 tests/test_zfs_capacity.py
      touch $out
    '';
    agent-instructions =
      pkgs.runCommand "agent-instructions-tests" {
        nativeBuildInputs = [pkgs.python3];
        AGENT_INSTRUCTIONS_INSTALLER = ../home/features/cli/ai/install-instructions.py;
      } ''
        python3 ${../tests/test_agent_instructions.py}
        touch $out
      '';
    # Glooko's login and export against intercepted pages in real Chromium,
    # and the n8n workflows run by the installed n8n against local fakes.
    # The scripts find the workflows and the diabetes app beside them in the
    # repository, so they run from the flake source.
  }
  // (let
    inherit (myPkgs.diabetes-app) python;
    n8n = self.nixosConfigurations.inari.config.services.n8n.package;
    script = name: argument:
      pkgs.runCommand name {
        # Without a font, text has no size and Playwright calls it invisible.
        FONTCONFIG_FILE = pkgs.makeFontsConf {fontDirectories = [pkgs.dejavu_fonts];};
      } ''
        export HOME=$TMPDIR PYTHONDONTWRITEBYTECODE=1 MPLCONFIGDIR=$TMPDIR/matplotlib
        ${python}/bin/python ${self}/tests/${name}.py ${argument}
        touch $out
      '';
  in {
    glooko-browser = script "glooko-browser" "${pkgs.chromium}/bin/chromium";
    glooko-download = script "glooko-download" "${pkgs.chromium}/bin/chromium";
    n8n-diabetes = script "n8n-diabetes" "${n8n}/bin/n8n";
    n8n-webuntis = script "n8n-webuntis" "${n8n}/bin/n8n";
  })
  // {
    backup-monitoring = import ../tests/backup-monitoring.nix {
      inherit pkgs;
      rules = self.nixosConfigurations.inari.config.services.grafana.provision.alerting.rules.settings;
    };
    actual-bridge = import ../tests/actual-bridge.nix {
      inherit pkgs;
      config = self.nixosConfigurations.inari.config;
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
    diabetes = myPkgs.diabetes-app.tests.unit;
    proton-mail-sorter = self.nixosConfigurations.inari.config.system.build.proton-mail-sorter-tests;
    dns-zones = dnsPackages.octodns-zones;
    # docs/options.md is generated by `just docs`; fail when it is stale.
    options-doc = pkgs.runCommand "options-doc-current" {} ''
      if ! diff -u ${../docs/options.md} ${optionsDoc} > diff; then
        echo "docs/options.md is out of date; run 'just docs'" >&2
        head -40 diff >&2
        exit 1
      fi
      touch $out
    '';
    dns-sync = dnsPackages.octodns-sync;
  }
