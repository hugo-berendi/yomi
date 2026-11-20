{
  lib,
  pkgs,
  hosts,
  statusUrl,
}: let
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };
  panel = {
    id,
    title,
    query,
    type,
    gridPos,
    unit ? "short",
    instant ? false,
  }: {
    inherit id title type gridPos datasource;
    fieldConfig.defaults = {
      inherit unit;
      noValue = "Keine Daten";
    };
    targets = [
      {
        inherit datasource instant;
        refId = "A";
        expr = query;
        range = !instant;
        format =
          if type == "table"
          then "table"
          else "time_series";
      }
    ];
  };
  stat = id: title: query: x: unit:
    panel {
      inherit id title query unit;
      type = "stat";
      gridPos = {
        inherit x;
        y = 4;
        w = 8;
        h = 4;
      };
      instant = true;
    };
  table = id: title: query: x: unit:
    panel {
      inherit id title query unit;
      type = "table";
      gridPos = {
        inherit x;
        y = 16;
        w = 8;
        h = 8;
      };
      instant = true;
    };
in
  pkgs.writeText "yomi-infrastructure.json" (builtins.toJSON {
    uid = "yomi-infrastructure";
    title = "Yomi · Infrastruktur";
    description = "Live-Metriken und Backup-Stand der von Inari erfassten Systeme.";
    tags = ["yomi" "infrastructure"];
    schemaVersion = 39;
    timezone = "browser";
    refresh = "30s";
    time = {
      from = "now-6h";
      to = "now";
    };
    links = [
      {
        title = "Dienststatus in Gatus";
        url = statusUrl;
        type = "link";
      }
    ];
    panels = [
      {
        id = 1;
        title = "Konfigurierte Hosts";
        type = "text";
        gridPos = {
          x = 0;
          y = 0;
          w = 24;
          h = 4;
        };
        options = {
          mode = "markdown";
          content = " **${lib.concatStringsSep " · " hosts}**\n\nInari liefert die Live-Metriken. Die Backuptabelle zeigt die verfügbaren Sicherungsdaten je Host.";
        };
      }
      (stat 2 "Exporter erreichbar" ''100 * avg(up)'' 0 "percent")
      (stat 3 "Inari · RAM verfügbar" ''100 * node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes'' 8 "percent")
      (stat 4 "Inari · Laufzeit" ''time() - node_boot_time_seconds'' 16 "s")
      (panel {
        id = 5;
        title = "Inari · CPU-Auslastung";
        query = ''100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))'';
        type = "timeseries";
        gridPos = {
          x = 0;
          y = 8;
          w = 12;
          h = 8;
        };
        unit = "percent";
      })
      (panel {
        id = 6;
        title = "Inari · RAM-Auslastung";
        query = ''100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'';
        type = "timeseries";
        gridPos = {
          x = 12;
          y = 8;
          w = 12;
          h = 8;
        };
        unit = "percent";
      })
      (table 7 "Letzte erfolgreiche Sicherungen · Alter"
        ''time() - max by (host, backup) (last_over_time(yomi_restic_last_success_timestamp_seconds[8d]))''
        0 "s")
      (table 8 "Inari · ZFS-Pools · 0 = gesund" ''max by (pool) (zfs_pool_health)'' 8 "short")
      (table 9 "Exporter · 1 = erreichbar" ''up'' 16 "short")
    ];
  })
