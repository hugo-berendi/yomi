{
  flake ? builtins.getFlake (toString ../.),
  host,
}: let
  system = flake.nixosConfigurations.${host};
  inherit (system.pkgs) lib;
  keys = [
    "User"
    "Group"
    "DynamicUser"
    "NoNewPrivileges"
    "PrivateTmp"
    "PrivateDevices"
    "PrivateMounts"
    "ProtectSystem"
    "ProtectHome"
    "ProtectClock"
    "ProtectControlGroups"
    "ProtectKernelLogs"
    "ProtectKernelModules"
    "ProtectKernelTunables"
    "ProtectProc"
    "PrivateUsers"
    "RestrictNamespaces"
    "RestrictSUIDSGID"
    "SystemCallArchitectures"
    "CapabilityBoundingSet"
    "AmbientCapabilities"
    "RestrictAddressFamilies"
    "SystemCallFilter"
    "ReadWritePaths"
    "StateDirectory"
    "CacheDirectory"
    "RuntimeDirectory"
  ];
  sources = name: lib.unique (map (d: d.file) (lib.filter (d: builtins.hasAttr name d.value) system.options.systemd.services.definitionsWithLocations));
in
  lib.mapAttrs (name: service: {
    settings = lib.filterAttrs (key: _: lib.elem key keys) service.serviceConfig;
    definitionSources = sources name;
    unitFile = toString system.config.systemd.units."${name}.service".unit;
    notes = lib.optional (service.serviceConfig.DynamicUser or false == true) "DynamicUser implies additional protections; unset does not mean disabled. Inspect the generated unit with systemd-analyze security for systemd's interpretation.";
  }) (lib.filterAttrs (_: s: s.enable) system.config.systemd.services)
