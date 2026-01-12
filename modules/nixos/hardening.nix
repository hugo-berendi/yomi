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
      description = "Override sets for common exceptions (network, devices, execSubprocess)";
    };
  };
  # }}}
  # {{{ Warnings
  config = {
    warnings = lib.pipe config.systemd.services [
      (lib.filterAttrs (
        _: svc:
          (svc.serviceConfig.DynamicUser or true) == false
          && !(svc.serviceConfig ? User)
      ))
      lib.attrNames
      (map (name: "Service '${name}' has DynamicUser=false but no User specified"))
    ];
  };
  # }}}
}
