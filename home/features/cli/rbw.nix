{
  config,
  pkgs,
  ...
}: {
  programs.rbw = {
    enable = true;
    settings = {
      base_url = "https://warden.hugo-berendi.de/";
      email = "personal@hugo-berendi.de";
      pinentry =
        if config.gtk.enable
        then pkgs.pinentry-gnome3
        else pkgs.pinentry-curses;
    };
  };
}
