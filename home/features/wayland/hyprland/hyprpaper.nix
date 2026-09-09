{
  config,
  lib,
  ...
}: {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      preload = ["${config.stylix.image}"];
      wallpaper =
        [",${config.stylix.image}"]
        ++ lib.forEach config.yomi.monitors (
          {name, ...}: "${name},${config.stylix.image}"
        );
    };
  };
}
