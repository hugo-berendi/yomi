{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.suwayomi;
in {
  options.yomi.suwayomi = {
    enable = lib.mkEnableOption "yomi's suwayomi integration";
  };

  config = lib.mkIf cfg.enable {
    services.suwayomi-server = {
      enable = true;
      openFirewall = true;
      user = config.yomi.pilot.name;
      settings = {
        server = {
          port = config.yomi.ports.suwayomi;
          systemTrayEnabled = true;
          downloadAsCbz = true;
          extensionRepos = [
            "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
          ];
        };
      };
    };
  };
}
