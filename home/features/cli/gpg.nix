{
  pkgs,
  config,
  ...
}: {
  services.gpg-agent = {
    enable = true;
    sshKeys = [
      "67D63C5F40CC55DA"
    ];
    pinentryPackage =
      if config.gtk.enable
      then pkgs.pinentry-gnome3
      else pkgs.pinentry-curses;
    enableFishIntegration = true;
    extraConfig = ''
      no-allow-external-cache
    '';
  };

  programs.gpg = {
    enable = true;
    publicKeys = [
      {
        source = ./yubikey.gpg;
        trust = "ultimate";
      }
    ];
  };

  yomi.persistence.at.state.apps.gpg.directories = [".gnupg"];
}
