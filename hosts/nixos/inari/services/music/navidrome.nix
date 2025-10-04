{
  config,
  pkgs,
  lib,
  ...
}: {
  sops.secrets.navidrome_env = lib.mkIf config.services.navidrome.enable {
    sopsFile = ../../secrets.yaml;
    owner = config.services.navidrome.user;
    group = config.services.navidrome.group;
  };

  yomi.nginx.at.navidrome.port = config.yomi.ports.navidrome;

  services.navidrome = {
    enable = false;
    environmentFile = config.sops.secrets.navidrome_env.path;
    settings = {
      Port = config.yomi.ports.navidrome;
      Address = "127.0.0.1";
      EnableInsightsCollector = false;
      LogLevel = "DEBUG";
      MusicFolder = "/raid5pool/media/music";
      DataFolder = "/raid5pool/data/navidrome";
      BaseUrl = config.yomi.nginx.at.navidrome.url;
      FFmpegPath = lib.getExe pkgs.ffmpeg-full;
      LastFM = {
        Enabled = true;
        Language = "en";
      };
      Prometheus = {
        Enabled = true;
        MetricsPath = "/metrics";
      };
      Scanner = {
        Enabled = true;
        Schedule = "@hourly";
      };
      UIWelcomeMessage = "Hello there ^_^";
    };
  };
}
