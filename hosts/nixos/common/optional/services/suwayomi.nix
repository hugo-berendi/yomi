{config, ...}: {
  services.suwayomi-server = {
    enable = true;
    openFirewall = true;
    user = config.satellite.pilot.name;
    setting = {
      server = {
        port = config.satellite.ports.suwayomi;
        systemTrayEnabled = true;
        downloadAsCbz = true;
        extensionRepos = [
          "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
        ];
      };
    };
  };
}
