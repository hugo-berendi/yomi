{config, ...}: {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = config.stylix.image;
          fit_mode = "cover";
        }
      ];
    };
  };
}
