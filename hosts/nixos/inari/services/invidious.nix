{
  config,
  pkgs,
  ...
}: {
  sops.secrets.invidious_hmac_key.sopsFile = ../secrets.yaml;
  sops.templates."invidious_hmac_key.json" = {
    content = ''{ "hmac_key": "${config.sops.placeholder.invidious_hmac_key}" }'';
    mode = "0444"; # I don't care about this key that much, as I'm the only user of this instance
  };

  systemd.tmpfiles.rules = ["z /var/lib/private 0700 root"];

  yomi.nginx.at.yt.port = config.yomi.ports.invidious;

  services.invidious = {
    enable = true;
    domain = config.yomi.nginx.at.yt.host;
    port = config.yomi.nginx.at.yt.port;
    hmacKeyFile = config.sops.templates."invidious_hmac_key.json".path;

    settings = {
      captcha_enabled = false;
      admins = ["hugo-berendi"];
      default_user_preferences = {
        default_home = "Subscriptions";
        comments = ["youtube" "reddit"];
        save_player_pos = true;
        automatic_instance_redirect = true;
      };
    };
    package = pkgs.invidious;
  };
}
