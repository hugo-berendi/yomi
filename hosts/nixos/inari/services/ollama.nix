{config, ...}: let
  modelsDir = "/var/ollama/models";
in {
  services.ollama = {
    enable = true;
    port = config.yomi.ports.ollama;
    models = modelsDir;
    loadModels = [
      "mistral-small3.1"
    ];
  };

  services.open-webui = {
    enable = true;
    port = config.yomi.ports.open-webui;
  };

  environment.persistence."/persist/local/cache".directories = [
    {
      inherit (config.services.jellyfin) user group;
      directory = "/var/cache/jellyfin";
      mode = "u=rwx,g=,o=";
    }
  ];
}
