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
        baseUri: http://127.0.0.1:${toString config.yomi.ports.komga}
        komgaUser: |-
          ${config.sops.placeholder.komga_user}
        komgaPassword: |-
          ${config.sops.placeholder.komga_password}
        thumbnailSizeLimit: 10485760
        eventListener:
          enabled: true
          libraries: []
        metadataUpdate:
          default:
            libraryType: WEBTOON
            updateModes: [ API ]
            aggregate: true
            seriesCovers: true
            bookCovers: true
            overrideExistingCovers: true
            postProcessing:
              seriesTitle: true
              seriesTitleLanguage: en

      metadataProviders:
        defaultProviders:
          mangaUpdates:
            priority: 10
            enabled: true
            seriesMetadata:
              thumbnail: true
            bookMetadata:
              thumbnail: true
          nautiljon:
            priority: 15
            enabled: true
          aniList:
            priority: 20
            enabled: true
            seriesMetadata:
              thumbnail: true
          yenPress:
            priority: 50
            enabled: true
          kodansha:
            priority: 60
            enabled: true
          viz:
            priority: 70
            enabled: true
          bookWalker:
            priority: 80
            enabled: true
          mangaDex:
            priority: 30
            enabled: true
            seriesMetadata:
              thumbnail: true
            bookMetadata:
              thumbnail: true
          bangumi:
            priority: 100
            enabled: true
          webtoons:
            priority: 130
            enabled: true
            mediaType: WEBTOON
            seriesMetadata:
              thumbnail: false
            bookMetadata:
              thumbnail: false
          hentag:
            priority: 6
            enabled: false
          mangaBaka:
            priority: 140
            enabled: true
            mode: API
            seriesMetadata:
              thumbnail: false
            bookMetadata:
              thumbnail: false

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
        ExecStart = "${lib.getExe pkgs.komf} ${config.sops.templates."komf-application.yml".path}";
        Restart = "on-failure";
        RestartSec = 10;
        ReadWritePaths = ["/var/lib/komf"];
      };
  };
}
