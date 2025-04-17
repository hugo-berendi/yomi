{config, ...}: {
  sops.secrets.immich_secrets = {
    sopsFile = ../secrets.yaml;
    owner = config.services.immich.user;
    group = config.services.immich.group;
  };

  sops.secrets.immich_oauth_client_secret = {
    sopsFile = ../secrets.yaml;
  };

  yomi.nginx.at.immich.port = config.yomi.ports.immich;
  yomi.cloudflared.at.immich-shared.port = config.yomi.ports.ipp;

  services.immich-public-proxy = {
    enable = true;
    immichUrl = config.yomi.nginx.at.immich.url;
    port = config.yomi.ports.ipp;
  };

  services.immich = {
    enable = true;
    port = config.yomi.ports.immich;
    host = "localhost";
    mediaLocation = "/raid5pool/media/photos";
    secretsFile = config.sops.secrets.immich_secrets.path;
    # settings = {
    #   server = {
    #     externalDomain = "https://immich.hugo-berendi.de/";
    #     loginPageMessage = "Hello traveler ^_^";
    #   };
    #   oauth = {
    #     enabled = true;
    #     autoLaunch = false;
    #     autoRegister = true;
    #     buttonText = "Login with Authentik";
    #     clientId = "crp82kCIMkscBZYMoEv3a18fmun1m9k8enomNGgU";
    #     # clientSecret = builtins.readFile config.sops.secrets.immich_oauth_client_secret.path; # "";
    #     issuerUrl = "https://authentik.hugo-berendi.de/application/o/immich/";
    #     scope = "openid email profile";
    #   };
    # };
  };
}
