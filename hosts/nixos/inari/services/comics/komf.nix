{
  config,
  lib,
  pkgs,
  ...
}: {
  users.users.komf = {
    isSystemUser = true;
    group = "komf";
    home = "/var/lib/komf";
  };
  users.groups.komf = {};

  sops.secrets.komga_user = {
    sopsFile = ../../secrets.yaml;
    owner = config.users.users.komf.name;
    group = config.users.users.komf.group;
  };
  sops.secrets.komga_password = {
    sopsFile = ../../secrets.yaml;
    owner = config.users.users.komf.name;
    group = config.users.users.komf.group;
  };

  sops.templates."komf-application.yml" = {
    owner = config.users.users.komf.name;
    group = config.users.users.komf.group;
    content = ''
      komga:
        baseUri: http://localhost:${toString config.yomi.ports.komga}
        komgaUser: ${config.sops.placeholder.komga_user}
        komgaPassword: ${config.sops.placeholder.komga_password}
        eventListener:
          enabled: true
          libraries: []

      metadataProviders:
        defaultProviders:
          mangaUpdates:
            priority: 10
            enabled: true
          aniList:
            priority: 20
            enabled: true
          mangaDex:
            priority: 30
            enabled: true

      metadataUpdate:
        default:
          updateModes: [ API ]

      server:
        port: ${toString config.yomi.ports.komf}
    '';
  };

  systemd.tmpfiles.rules = ["d /var/lib/komf 0750 ${config.users.users.komf.name} ${config.users.users.komf.group}"];

  systemd.services.komf = {
    description = "Komf metadata fetcher";
    after = ["komga.service"];
    wants = ["komga.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig =
      (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
      // {
        Type = "simple";
        User = config.users.users.komf.name;
        Group = config.users.users.komf.group;
        WorkingDirectory = "/var/lib/komf";
        ExecStart = "${lib.getExe pkgs.komf} --config ${config.sops.templates."komf-application.yml".path}";
        Restart = "on-failure";
        RestartSec = 10;
        ReadWritePaths = ["/var/lib/komf"];
      };
  };
}
