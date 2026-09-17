{
  config,
  lib,
  ...
}: let
  # {{{ Presets
  # Base tier - minimal hardening for all services
  base = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
  };

  # Standard tier - moderate hardening
  standard =
    base
    // {
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    };

  # Strict tier - maximum lockdown
  strict =
    standard
    // {
      CapabilityBoundingSet = [""];
      PrivateUsers = true;
      ProtectProc = "invisible";
      RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
      SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
    };
  # }}}
  # {{{ Overrides
  overrides = {
    network = {
      PrivateNetwork = lib.mkForce false;
      RestrictAddressFamilies = lib.mkForce ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
    };
    devices = {
      PrivateDevices = lib.mkForce false;
    };
    execSubprocess = {
      SystemCallFilter = lib.mkForce ["@system-service"];
    };
  };
  cfg = config.yomi.hardening;
  # }}}
in {
  # {{{ Options
  options.yomi.hardening = {
    presets = lib.mkOption {
      type = lib.types.attrs;
      default = {inherit base standard strict;};
      readOnly = true;
      description = "Predefined systemd hardening tiers (base, standard, strict)";
    };

    overrides = lib.mkOption {
      type = lib.types.attrs;
      default = overrides;
      readOnly = true;
      description = ''
        Override sets for common exceptions (network, devices, execSubprocess).

        Superseded by `yomi.hardening.services`, and kept only for call sites
        that have not migrated. Two things make it sharp: merged into a tier
        that does not set RestrictAddressFamilies it *adds* one rather than
        relaxing it, and two mkForce definitions of that list concatenate
        instead of replacing, so a strict service ends up listing AF_INET,
        AF_INET6 and AF_UNIX twice.
      '';
    };

    services = lib.mkOption {
      default = {};
      description = ''
        Services to harden, by unit name.

        Replaces spelling out
        `lib.mkMerge [(lib.mapAttrs (_: lib.mkForce) presets.<tier>) ...]` at
        each call site. The tier is computed as one attrset and applied once,
        so relaxations actually relax, and every name is checked against a unit
        that really exists.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          tier = lib.mkOption {
            type = lib.types.enum ["base" "standard" "strict"];
            default = "standard";
            description = "Which hardening tier to apply.";
          };

          allowNetwork = lib.mkEnableOption ''
            netlink sockets, for services that resolve names or query links.

            A no-op below the strict tier, which is the only one that restricts
            address families at all
          '';

          allowDevices = lib.mkEnableOption "access to physical devices (disables PrivateDevices)";

          allowSubprocesses = lib.mkEnableOption ''
            the privileged and resource syscall groups, for services that spawn
            helpers. Only meaningful at the strict tier
          '';

          readWritePaths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Paths to keep writable under ProtectSystem=strict. Appended to
              whatever the upstream module already declares rather than
              replacing it.
            '';
          };

          extraConfig = lib.mkOption {
            type = lib.types.attrs;
            default = {};
            description = "Additional serviceConfig merged after the tier.";
          };
        };
      });
    };
  };
  # }}}
  # {{{ Application
  config = let
    tiers = {inherit base standard strict;};

    # Resolved as a plain attrset before it reaches the module system, so a
    # relaxation replaces a value instead of being concatenated onto it.
    resolve = svc: let
      tier = tiers.${svc.tier};

      withNetwork =
        if svc.allowNetwork && tier ? RestrictAddressFamilies
        then tier // {RestrictAddressFamilies = tier.RestrictAddressFamilies ++ ["AF_NETLINK"];}
        else tier;

      withDevices =
        if svc.allowDevices
        then builtins.removeAttrs withNetwork ["PrivateDevices"]
        else withNetwork;

      withSubprocesses =
        if svc.allowSubprocesses && withDevices ? SystemCallFilter
        then withDevices // {SystemCallFilter = ["@system-service"];}
        else withDevices;
    in
      withSubprocesses;
  in {
    # A unit conjured purely out of hardening settings has no ExecStart and
    # systemd refuses it -- which is how karakeep.service came to exist, and
    # hardened nothing, while the karakeep services that do exist ran open.
    # Checking for existence would not catch it, since defining serviceConfig
    # creates the name; the absence of an ExecStart is the tell.
    assertions =
      lib.mapAttrsToList (name: _: {
        assertion =
          (config.systemd.services.${name}.serviceConfig or {})
          ? ExecStart
          || (config.systemd.services.${name}.script or "") != "";
        message = ''
          yomi.hardening.services.${name} targets a unit with no ExecStart.

          Nothing else defines ${name}.service, so this would harden an empty
          unit that systemd refuses to load, and leave the real services open.
          Check the unit names the module actually ships.
        '';
      })
      cfg.services;

    systemd.services =
      lib.mapAttrs (_: svc: {
        serviceConfig = lib.mkMerge [
          (lib.mapAttrs (_: lib.mkForce) (resolve svc))
          (lib.optionalAttrs (svc.readWritePaths != []) {ReadWritePaths = svc.readWritePaths;})
          svc.extraConfig
        ];
      })
      cfg.services;

    warnings = lib.pipe config.systemd.services [
      (lib.filterAttrs (
        _: svc:
          (svc.serviceConfig.DynamicUser or true)
          == false
          && !(svc.serviceConfig ? User)
      ))
      lib.attrNames
      (map (name: "Service '${name}' has DynamicUser=false but no User specified"))
    ];
  };
  # }}}
}
