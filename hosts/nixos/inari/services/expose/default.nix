# Pangolin publishes inari's public sites through ebisu; each service declares
# its own endpoint in yomi.web.at. Private access goes through NetBird
# (../netbird.nix), whose devices get the LAN's ports.
{
  config,
  lib,
  ...
}: {
  yomi.expose.enable = true;
  sops.secrets.pangolin_newt_environment = lib.mkIf config.yomi.expose.enable {
    sopsFile = ../../secrets.yaml;
  };
  yomi.expose.environmentFile = lib.mkIf config.yomi.expose.enable config.sops.secrets.pangolin_newt_environment.path;

  # EU membership, not Schengen or EEA. Country matches pass to normal auth.
  yomi.expose.allowedCountries = ["AT" "BE" "BG" "HR" "CY" "CZ" "DK" "EE" "FI" "FR" "DE" "GR" "HU" "IE" "IT" "LV" "LT" "LU" "MT" "NL" "PL" "PT" "RO" "SK" "SI" "ES" "SE"];
}
