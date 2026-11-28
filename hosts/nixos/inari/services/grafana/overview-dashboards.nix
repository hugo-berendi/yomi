{
  config,
  pkgs,
}: let
  web = config.yomi.web.at;
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };
  dashboard = uid: title: panels:
    (pkgs.formats.json {}).generate "${uid}.json" {
      inherit uid title panels;
      schemaVersion = 39;
      refresh = "1m";
      time = {
        from = "now-24h";
        to = "now";
      };
    };
  textPanel = id: y: h: title: content: {
    inherit id title;
    type = "text";
    gridPos = {
      inherit y h;
      x = 0;
      w = 24;
    };
    options = {
      mode = "markdown";
      inherit content;
    };
  };
  series = id: x: y: w: title: unit: expr: legendFormat: {
    inherit id title datasource;
    type = "timeseries";
    gridPos = {
      inherit x y w;
      h = 9;
    };
    fieldConfig.defaults = {
      inherit unit;
      min = 0;
    };
    targets = [
      {
        inherit datasource expr legendFormat;
        refId = "A";
      }
    ];
    options.tooltip.mode = "multi";
  };
  links = entries: builtins.concatStringsSep "\n" (map (entry: "- [${entry.name}](${entry.url}) · ${entry.description}") entries);
  internal = name: uid: description: {
    inherit name description;
    url = "/d/${uid}";
  };
  external = name: service: description: {
    inherit name description;
    url = web.${service}.url;
  };
in {
  home = dashboard "yomi-home" "Yomi · Übersicht" [
    (textPanel 1 0 8 "Monitoring" (links [
      (internal "Dienststatus" "yomi-service-status" "Erreichbarkeit und Antwortzeiten")
      (internal "Geplante Jobs" "yomi-healthchecks" "Healthchecks-Status und Ping-Verlauf")
      (internal "Infrastruktur" "yomi-infrastructure" "Hosts, Speicher und Backups")
      (internal "Infrastrukturkarte" "yomi-topology" "Netzwerkpfade, Datenflüsse und Webdienste")
      (internal "Node Exporter" "rYdddlPWk" "Detaillierte Systemmetriken")
      (internal "CLIProxyAPI" "cliproxyapi-usage" "Tokens, Anfragen und Fehler je Konto")
      {
        name = "Alerts";
        url = "/alerting/list";
        description = "Regeln und aktuelle Alarmzustände";
      }
    ]))
    (textPanel 2 8 7 "Fachansichten" (links [
      (internal "Medien" "yomi-media" "Bibliothek, Untertitel und Indexer")
      (external "Budget" "budget" "Actual Budget öffnen")
      (external "Diabetes" "diabetes" "Glukoseberichte öffnen")
    ]))
    (textPanel 3 15 6 "Weitere Monitoring-Ansichten" (links [
      (internal "Host-Flotte" "yomi-fleet" "Beszel-Hoststatus, CPU, RAM und Speicher")
    ]))
  ];
  healthchecks = let
    sqlSource = {
      type = "postgres";
      uid = "yomi-healthchecks-db";
    };
    sqlPanel = {
      id,
      title,
      type,
      format,
      y,
      rawSql,
    }: {
      inherit id title type;
      datasource = sqlSource;
      gridPos = {
        inherit y;
        x = 0;
        w = 24;
        h = 10;
      };
      targets = [
        {
          inherit format rawSql;
          datasource = sqlSource;
          refId = "A";
          editorMode = "code";
          rawQuery = true;
        }
      ];
    };
  in
    dashboard "yomi-healthchecks" "Yomi · Geplante Jobs" [
      (sqlPanel {
        id = 1;
        title = "Aktueller Check-Status";
        type = "table";
        format = "table";
        y = 0;
        rawSql = "SELECT name AS \"Job\", state AS \"Status\", last_ping AS \"Letzter Ping\", alert_after AS \"Alarm ab\", duration_seconds AS \"Dauer (s)\" FROM grafana_healthchecks.checks ORDER BY (state = 'down') DESC, name";
      })
      (sqlPanel {
        id = 2;
        title = "Pings im Zeitverlauf";
        type = "timeseries";
        format = "time_series";
        y = 10;
        rawSql = "SELECT $__timeGroupAlias(created, $__interval), COALESCE(NULLIF(kind, ''), 'success') AS metric, count(*) AS value FROM grafana_healthchecks.pings WHERE $__timeFilter(created) GROUP BY 1, 2 ORDER BY 1";
      })
      (textPanel 3 20 4 "Checks verwalten" (links [
        (external "Healthchecks" "ping" "Konfiguration, Ping-URLs und Benachrichtigungen")
      ]))
    ];
  status = dashboard "yomi-service-status" "Yomi · Dienststatus" [
    {
      id = 1;
      title = "Aktueller Dienststatus";
      inherit datasource;
      type = "table";
      gridPos = {
        x = 0;
        y = 0;
        w = 24;
        h = 14;
      };
      targets = [
        {
          inherit datasource;
          refId = "A";
          expr = "max by (group, name) (gatus_results_endpoint_success)";
          format = "table";
          instant = true;
          range = false;
        }
      ];
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName.Time = true;
            renameByName = {
              group = "Gruppe";
              name = "Dienst";
              Value = "Status";
            };
          };
        }
      ];
      fieldConfig.defaults.mappings = [
        {
          type = "value";
          options = {
            "0" = {
              text = "Fehler";
              color = "red";
            };
            "1" = {
              text = "Erreichbar";
              color = "green";
            };
          };
        }
      ];
    }
    (series 2 0 14 24 "Antwortzeit im Verlauf" "s"
      "max by (group, name) (gatus_results_duration_seconds)" "{{group}} / {{name}}")
  ];
  fleet = dashboard "yomi-fleet" "Yomi · Host-Flotte" [
    (series 1 0 0 12 "Agent erreichbar" "bool_on_off" "beszel_system_up" "{{host}}")
    (series 2 12 0 12 "CPU" "percent" "beszel_cpu_percent" "{{host}}")
    (series 3 0 9 12 "Arbeitsspeicher" "percent" "beszel_memory_percent" "{{host}}")
    (series 4 12 9 12 "Datenträger" "percent" "beszel_disk_percent" "{{host}}")
    (textPanel 5 18 5 "Host- und Containerdetails" (links [
      (external "Beszel" "monitoring" "Historische Messwerte und Containeransicht")
    ]))
  ];
  media = dashboard "yomi-media" "Yomi · Medien" [
    (series 1 0 0 12 "Filme in Radarr" "short"
      ''label_replace(sum(radarr_movie_total), "series", "Gesamt", "", "") or label_replace(sum(radarr_movie_downloaded_total), "series", "Heruntergeladen", "", "") or label_replace(sum(radarr_movie_missing_total), "series", "Fehlend", "", "")'' "{{series}}")
    (series 2 12 0 12 "Episoden in Sonarr" "short"
      ''label_replace(sum(sonarr_episode_total), "series", "Gesamt", "", "") or label_replace(sum(sonarr_episode_downloaded_total), "series", "Heruntergeladen", "", "") or label_replace(sum(sonarr_episode_missing_total), "series", "Fehlend", "", "")'' "{{series}}")
    (series 3 0 9 12 "Offene Untertitel in Bazarr" "short" "sum(bazarr_subtitles_wanted_total)" "Untertitel")
    (series 4 12 9 12 "Aktive Prowlarr-Indexer" "short" "sum(prowlarr_indexer_enabled_total)" "Indexer")
    (textPanel 5 18 5 "Medien verwalten" (links [
      (external "Radarr" "radarr" "Filme")
      (external "Sonarr" "sonarr" "Serien")
      (external "Jellyfin" "media" "Wiedergabe")
    ]))
  ];
}
