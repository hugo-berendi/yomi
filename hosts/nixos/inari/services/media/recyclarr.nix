{config, ...}: {
  nixarr.recyclarr = {
    enable = false;
    schedule = "daily";
    configuration = {
      sonarr = {
        series = {
          base_url = "http://localhost:${toString config.yomi.ports.sonarr}";
          api_key = "!env_var SONARR_API_KEY";
          quality_definition = {type = "series";};
          delete_old_custom_formats = true;
        };
      };
      radarr = {
        movies = {
          base_url = "http://localhost:${toString config.yomi.ports.radarr}";
          api_key = "!env_var RADARR_API_KEY";
          quality_definition = {type = "movie";};
          delete_old_custom_formats = true;
        };
      };
    };
  };

  # Provide SONARR_API_KEY and RADARR_API_KEY via sops-nix managed env file
  sops.secrets.recyclarr_env.sopsFile = ../../secrets.yaml;
  systemd.services.recyclarr.serviceConfig.EnvironmentFile = [
    config.sops.secrets.recyclarr_env.path
  ];
}
