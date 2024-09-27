{
  config,
  pkgs,
  ...
}: {
  programs.rbw = {
    enable = true;
    settings = {
      base_url = ""; # will be set when I setup my nas
      identity_url = null; # TODO: find out what that is
      email = "bitwarden@hugo-berendi.de";
      pinentry =
        if config.gtk.enable
        then pkgs.pinentry-gnome3
        else pkgs.pinentry-curses;
    };
  };
}
