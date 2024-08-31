# I use bitwarden as my main password manager.
#
# This currently acts as a simple local libsecret store.
{
  pkgs,
  upkgs,
  config,
  lib,
  ...
}: let
  storePath = "${config.home.homeDirectory}/.password-store";
  gitRepoUrl = "git@github.com:hugo-berendi/pwd-store.git";
in {
  programs.password-store = {
    enable = true;
    package = upkgs.pass.withExtensions (exts:
      with exts; [
        pass-otp
        pass-import
        # pass-audit # does not compile
        pass-genphrase
        pass-update
        pass-checkup
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

  # Activation script to clone the repo automatically using SSH
  home.activation.clone-password-store = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Clone the repo if it doesn't already exist
    if [ ! -d ${storePath}/.git ]; then
      echo "Cloning password store repository using SSH..."
      ${lib.getExe pkgs.gitFull} clone ${gitRepoUrl} ${storePath}
    else
      echo "Password store repository already exists."
    fi
  '';
}
