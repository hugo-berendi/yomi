{
  config,
  lib,
  pkgs,
  ...
}: let
  comicDir = "/raid5pool/media/comics";
  komgaLibraryName = "Suwayomi";
  komgaPort = config.yomi.nginx.at.komga.port;
in {
  yomi.nginx.at.komga.port = config.yomi.ports.komga;

  services.komga = {
    enable = true;
    settings = {server.port = komgaPort;};
  };

  systemd.services.komga-create-suwayomi-library = {
    description = "Ensure Komga Suwayomi library exists";
    after = ["komga.service"];
    wants = ["komga.service"];
    wantedBy = ["multi-user.target"];
    path = [
      pkgs.curl
      pkgs.jq
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
    };
    script = ''
      user="$(tr -d '\n' < ${config.sops.secrets.komga_user.path})"
      password="$(tr -d '\n' < ${config.sops.secrets.komga_password.path})"

      libraries="$(curl --silent --show-error --fail --user "$user:$password" "http://127.0.0.1:${toString komgaPort}/api/v1/libraries")"

      if jq --exit-status --arg name "${komgaLibraryName}" --arg root "${comicDir}" 'any(.[]; .name == $name or .root == $root)' >/dev/null <<<"$libraries"; then
        exit 0
      fi

      curl --silent --show-error --fail \
        --user "$user:$password" \
        --header "Content-Type: application/json" \
        --data "$(jq -n --arg name "${komgaLibraryName}" --arg root "${comicDir}" '{
          name: $name,
          root: $root,
          importComicInfoSeries: true,
          importComicInfoCollection: true,
          importComicInfoReadList: true,
          importComicInfoBook: true,
          importComicInfoSeriesAppendVolume: true,
          importEpubSeries: true,
          importEpubBook: true,
          importMylarSeries: true,
          importLocalArtwork: true,
          importBarcodeIsbn: true,
          scanForceModifiedTime: false,
          scanInterval: "EVERY_12H",
          scanOnStartup: true,
          scanCbx: true,
          scanPdf: true,
          scanEpub: true,
          repairExtensions: true,
          convertToCbz: false,
          emptyTrashAfterScan: false,
          seriesCover: "FIRST",
          hashFiles: false,
          hashPages: false,
          hashKoreader: false,
          analyzeDimensions: false,
          scanDirectoryExclusions: []
        }')" \
        "http://127.0.0.1:${toString komgaPort}/api/v1/libraries"
    '';
  };

  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.komga.stateDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.komga.user;
      group = config.services.komga.group;
    }
  ];
}
