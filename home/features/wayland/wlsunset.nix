{
  pkgs,
  config,
  ...
}: let
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

    latitude = config.yomi.location.latitude;
    longitude = config.yomi.location.longitude;
  };

  home.packages = [wlsunset-toggle];
}
