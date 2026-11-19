{
  config,
  lib,
  ...
}: {
  imports = [./expose-vpn.nix];
  yomi.expose.enable = true;
  sops.secrets.pangolin_newt_environment = lib.mkIf config.yomi.expose.enable {
    sopsFile = ../secrets.yaml;
  };
  yomi.expose.environmentFile = lib.mkIf config.yomi.expose.enable config.sops.secrets.pangolin_newt_environment.path;

  # EU membership, not Schengen or EEA. Country matches pass to normal auth.
  yomi.expose.allowedCountries = ["AT" "BE" "BG" "HR" "CY" "CZ" "DK" "EE" "FI" "FR" "DE" "GR" "HU" "IE" "IT" "LV" "LT" "LU" "MT" "NL" "PL" "PT" "RO" "SK" "SI" "ES" "SE"];
  # Per-service grants keep administrative interfaces off the public gateway.
  yomi.expose.private =
    lib.mapAttrs (name: ports: {
      destination = "127.0.0.1";
      alias = "${name}.inari.internal";
      tcpPorts = ports;
      users = [config.yomi.pilot.email];
    }) {
      ssh = [22];
      grafana = [config.yomi.ports.grafana];
      homepage = [config.yomi.ports.homepage];
      status = [config.yomi.ports.gatus];
      adguard = [config.yomi.ports.adguard];
    }
    // {
      home-exit = {
        # Verify the exit node's LAN reachability before granting full egress.
        enable = false;
        mode = "exit-node";
        users = [config.yomi.pilot.email];
      };
    };
}
