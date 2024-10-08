{pkgs, ...}: let
  systemctl = "${pkgs.systemd}/bin/systemctl";

  wlsunset-toggle = pkgs.writeShellScriptBin "wlsunset-toggle" ''
    if [ "active" = "$(systemctl --user is-active wlsunset.service)" ]
    then
      ${systemctl} --user stop wlsunset.service
      echo "Stopped wlsunset"
    else
      ${systemctl} --user start wlsunset.service
      echo "Started wlsunset"
    fi
  '';
in {
  services.wlsunset = {
    enable = true;

    # Random German coordinates
    latitude = "51.23";
    longitude = "14.83";
  };

  home.packages = [wlsunset-toggle];
}
