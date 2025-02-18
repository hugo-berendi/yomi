{...}: let
  modelsDir = "/var//ollama/models";
in {
  services.ollama = {
    enable = true;
    models = modelsDir;
    loadModels = [];
  };
  environment.persistence."/persist/local/cache".directories = [
    {
      inherit (config.services.jellyfin) user group;
      directory = "/var/cache/jellyfin";
      mode = "u=rwx,g=,o=";
    }
  ];
}
