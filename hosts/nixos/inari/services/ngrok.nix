{inputs,config,...}: {
  imports = [inputs.ngrok.nixosModules.ngrok];

  sops.secrets.ngrok_authtoken.sopsFile = ../secrets.yaml;
  sops.secrets.ngrok_api_key.sopsFile = ../secrets.yaml; 

  sops.templates."ngrok.yml" = {
    content = ''
      version: 3

      agent:
        authtoken: ${config.sops.placeholder.ngrok_authtoken}
        api_key: ${config.sops.placeholder.ngrok_api_key}
    '';
    owner = "ngrok";
    mode = "0777";
  };

  services.ngrok = {
    enable = true;
    extraConfigFiles = [
      config.sops.templates."ngrok.yml".path
    ];
  };
}
