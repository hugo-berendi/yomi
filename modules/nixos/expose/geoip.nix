{
  config,
  lib,
  pkgs,
  outputs,
  ...
}: let
  cfg = config.yomi.expose.server;
  geo = cfg.geoip;
  database = "${geo.databaseDirectory}/GeoLite2-City.mmdb";
  asnDatabase = "${geo.databaseDirectory}/GeoLite2-ASN.mmdb";
  sites = map (host: outputs.nixosConfigurations.${host}.config.yomi.expose) cfg.sourceHosts;
in {
  options.yomi.expose.server.geoip = {
    enable = lib.mkEnableOption "local IP geolocation and ASN lookups for blocking and Pangolin analytics";
    databaseDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/GeoIP";
      description = "Directory containing GeoLite2-City.mmdb and GeoLite2-ASN.mmdb.";
    };
    update = {
      enable = lib.mkEnableOption "weekly GeoLite2 downloads directly from MaxMind";
      accountId = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "MaxMind account ID.";
      };
      licenseKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Runtime MaxMind license key file outside the Nix store.";
      };
    };
  };
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = geo.enable || lib.all (site: lib.all (e: e.allowedCountries == [] && e.blockedCountries == [] && e.blockedASNs == [] && !lib.any (r: lib.elem r.match ["country" "country_is_not" "asn"]) e.rules) (lib.attrValues (lib.filterAttrs (_: e: e.enable) site.at))) sites;
          message = "Expose country/ASN rules require server.geoip.enable and current GeoLite2 databases.";
        }
      ];
    }
    (lib.mkIf geo.enable {
      services.pangolin.settings.server = {
        maxmind_db_path = database;
        maxmind_asn_path = asnDatabase;
      };
      systemd.services.pangolin.preStart = lib.mkBefore ''
        ${pkgs.coreutils}/bin/test -r ${lib.escapeShellArg database}
        ${pkgs.coreutils}/bin/test -r ${lib.escapeShellArg asnDatabase}
      '';
      # Pangolin opens MMDB readers at startup. Reload only after a database
      # changes; a weekly no-op update must not bounce the control plane.
      systemd.paths.expose-geoip-reload = {
        wantedBy = ["multi-user.target"];
        pathConfig = {
          PathChanged = [database asnDatabase];
          Unit = "expose-geoip-reload.service";
        };
      };
      systemd.services.expose-geoip-reload = {
        after = ["geoipupdate.service"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl try-restart pangolin.service";
        };
      };
    })
    (lib.mkIf (geo.enable && geo.update.enable) {
      assertions = [
        {
          assertion = geo.update.accountId != null && geo.update.licenseKeyFile != null && lib.hasPrefix "/" geo.update.licenseKeyFile && !lib.hasPrefix "/nix/store/" geo.update.licenseKeyFile;
          message = "GeoIP updates require a MaxMind account ID and runtime license key file.";
        }
      ];
      services.geoipupdate = {
        enable = true;
        settings = {
          AccountID =
            if geo.update.accountId == null
            then 0
            else geo.update.accountId;
          LicenseKey =
            if geo.update.licenseKeyFile == null
            then "/run/secrets/maxmind-license"
            else geo.update.licenseKeyFile;
          EditionIDs = ["GeoLite2-City" "GeoLite2-ASN"];
          DatabaseDirectory = geo.databaseDirectory;
        };
      };
      systemd.services.pangolin = {
        requires = ["geoipupdate.service"];
        after = ["geoipupdate.service"];
      };
    })
  ]);
}
