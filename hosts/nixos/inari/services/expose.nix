{
  config,
  lib,
  upkgs,
  ...
}: let
  privateHost = alias: tcpPorts: {
    destination = "127.0.0.1";
    inherit alias tcpPorts;
    users = [config.yomi.pilot.email];
  };
  # The HTTPS vhosts share the same listener and pilot grant. Keep their
  # canonical hostnames so clients use the existing certificates and origins.
  internalWeb = lib.mapAttrs' (name: endpoint:
    lib.nameValuePair "https-${name}" (privateHost endpoint.host [443]))
  (lib.filterAttrs (_: endpoint: endpoint.enable) config.yomi.nginx.at);
in {
  imports = [./expose-vpn.nix];
  # Default-route traffic must not inherit Newt's access to local services.
  services.newt.package = upkgs.fosrl-newt.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./newt-public-exit.patch];
  });
  # The exit filter runs in Newt's userspace network stack.
  services.newt.settings = {
    "native=false" = true;
    "native-main=false" = true;
  };
  yomi.expose.enable = true;
  sops.secrets.pangolin_newt_environment = lib.mkIf config.yomi.expose.enable {
    sopsFile = ../secrets.yaml;
  };
  yomi.expose.environmentFile = lib.mkIf config.yomi.expose.enable config.sops.secrets.pangolin_newt_environment.path;

  # EU membership, not Schengen or EEA. Country matches pass to normal auth.
  yomi.expose.allowedCountries = ["AT" "BE" "BG" "HR" "CY" "CZ" "DK" "EE" "FI" "FR" "DE" "GR" "HU" "IE" "IT" "LV" "LT" "LU" "MT" "NL" "PL" "PT" "RO" "SK" "SI" "ES" "SE"];
  # Only the pilot receives these private aliases. The HTTPS aliases share
  # one nginx listener, so they are not separate access boundaries.
  yomi.expose.private =
    lib.mapAttrs (name: ports: privateHost "${name}.inari.internal" ports) {
      ssh = [22];
      grafana = [config.yomi.ports.grafana];
      homepage = [config.yomi.ports.homepage];
      status = [config.yomi.ports.gatus];
      adguard = [config.yomi.ports.adguard];
    }
    // internalWeb
    // {
      host-ssh = privateHost "${config.networking.hostName}.${config.yomi.dns.domain}" [22];
      forgejo-ssh = privateHost config.services.forgejo.settings.server.SSH_DOMAIN [22];
      mail = privateHost "mail.${config.yomi.dns.domain}" [465 993];
      home-exit = {
        mode = "exit-node";
        users = [config.yomi.pilot.email];
      };
    };
}
