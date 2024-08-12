# I use bitwarden as my main password manager.
#
# This currently acts as a simple local libsecret store.
{
  pkgs,
  config,
  lib,
  ...
}: let
  storePath = "${config.home.homeDirectory}/.password-store";
in {
  programs.password-store = {
    enable = true;
    package = pkgs.pass-wayland.withExtensions (exts:
      with exts; [
        pass-otp
        pass-import
        pass-audit
      ]);
    settings.PASSWORD_STORE_DIR = storePath;
  };

  services.pass-secret-service = {
    inherit storePath;
    enable = true;
  };

  home.packages = with pkgs; [
    tessen
  ];

  satellite.persistence.at.data.apps.pass.directories = [storePath];
}
