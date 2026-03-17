{
  config,
  pkgs,
  ...
}: let
  port = config.yomi.ports.sable;
  matrixHost = "matrix.${config.yomi.dns.domain}";
  sableConfig = pkgs.writeText "sable-config.json" (
    builtins.toJSON {
      defaultHomeserver = 0;
      homeserverList = [
        matrixHost
        "matrix.org"
        "mozilla.org"
        "unredacted.org"
        "sable.moe"
        "kendama.moe"
      ];
      allowCustomHomeservers = true;
      elementCallUrl = null;
      disableAccountSwitcher = false;
      hideUsernamePasswordFields = false;
      pushNotificationDetails = {
        pushNotifyUrl = "https://cinny.cc/_matrix/push/v1/notify";
        vapidPublicKey = "BHLwykXs79AbKNiblEtZZRAgnt7o5_ieImhVJD8QZ01MVwAHnXwZzNgQEJJEU3E5CVsihoKtb7yaNe5x3vmkWkI";
        webPushAppID = "cc.cinny.web";
      };
      slidingSync.enabled = true;
      featuredCommunities = {
        openAsDefault = false;
        spaces = [
          "#sable:sable.moe"
          "#community:matrix.org"
          "#space:unredacted.org"
          "#science-space:matrix.org"
          "#libregaming-games:tchncs.de"
          "#mathematics-on:matrix.org"
        ];
        rooms = [
          "#announcements:sable.moe"
          "#freesoftware:matrix.org"
          "#pcapdroid:matrix.org"
          "#gentoo:matrix.org"
          "#PrivSec.dev:arcticfoxes.net"
          "#disroot:aria-net.org"
        ];
        servers = [
          matrixHost
          "matrix.org"
          "mozilla.org"
          "unredacted.org"
        ];
      };
      hashRouter = {
        enabled = false;
        basename = "/";
      };
    }
  );
in {
  yomi.nginx.at.sable.port = port;

  virtualisation.oci-containers.containers.sable = {
    image = "ghcr.io/sableclient/sable@sha256:2b031ef97230bd93bd02f8629c9ce8025a0df549f146a961c8145276a05c58b0";
    ports = ["127.0.0.1:${toString port}:8080"];
    volumes = ["${sableConfig}:/app/config.json:ro"];
    log-driver = "journald";
  };
}
