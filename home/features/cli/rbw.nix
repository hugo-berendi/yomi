{
  config,
  pkgs,
  ...
}: {
  programs.rbw = {
    enable = true;
    settings = {
      base_url = "https://warden.hugo-berendi.de/";
      email = config.yomi.pilot.email;
      pinentry =
        if config.gtk.enable
        then pkgs.pinentry-gnome3
        else pkgs.pinentry-curses;
    };
  };
}
