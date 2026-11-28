{pkgs}: let
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };
  panel = {
    id,
    title,
    metric,
    unit,
    type,
    gridPos,
    window ? null,
  }: {
    inherit id title datasource type gridPos;
    description = "Nur über CLIProxyAPI erfasste Nutzung. Abo-Limits und direkte Nutzung beim Anbieter sind hier nicht enthalten.";
    fieldConfig.defaults = {
      inherit unit;
      min = 0;
      decimals = 0;
      color.mode = "palette-classic-by-name";
    };
    targets = [
      {
        inherit datasource;
        refId = "A";
        legendFormat = "{{account}}";
        instant = type == "bargauge";
        range = type == "timeseries";
        expr = "sum by (account) (increase(${metric}[${
          if type == "bargauge"
          then
            (
              if window == null
              then "$__range"
              else window
            )
          else "$__rate_interval"
        }]))";
      }
    ];
    options =
      if type == "bargauge"
      then {
        orientation = "horizontal";
        displayMode = "basic";
        reduceOptions.calcs = ["lastNotNull"];
      }
      else {
        legend.placement = "bottom";
        tooltip.mode = "multi";
      };
  };
  quota = id: x: window: title: {
    inherit id title datasource;
    type = "bargauge";
    description = "Vom Anbieter gemeldetes Abo-Limit. Fehlende Balken bedeuten, dass der Anbieter für das Konto kein aktuelles Fenster liefert.";
    gridPos = {
      inherit x;
      y = 0;
      w = 12;
      h = 7;
    };
    fieldConfig.defaults = {
      unit = "percent";
      min = 0;
      max = 100;
      thresholds.steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 80;
        }
        {
          color = "red";
          value = 95;
        }
      ];
    };
    options = {
      orientation = "horizontal";
      displayMode = "basic";
      reduceOptions.calcs = ["lastNotNull"];
    };
    targets = [
      {
        inherit datasource;
        refId = "A";
        instant = true;
        range = false;
        legendFormat = "{{account}}";
        expr = ''cliproxyapi_quota_used_percent{window="${window}"}'';
      }
    ];
  };
in
  (pkgs.formats.json {}).generate "cliproxyapi-usage.json" {
    uid = "cliproxyapi-usage";
    title = "CLIProxyAPI · Kontoverbrauch";
    tags = ["CLIProxyAPI"];
    schemaVersion = 39;
    refresh = "30s";
    time = {
      from = "now-24h";
      to = "now";
    };
    panels = [
      (quota 6 0 "5h" "Abo-Limit · 5 Stunden")
      (quota 7 12 "7d" "Abo-Limit · Woche")
      {
        id = 8;
        title = "Nächster Reset je Konto und Limit";
        inherit datasource;
        type = "table";
        gridPos = {
          x = 0;
          y = 7;
          w = 24;
          h = 8;
        };
        targets = [
          {
            inherit datasource;
            refId = "A";
            instant = true;
            range = false;
            format = "table";
            expr = "max by (account, window) (1000 * cliproxyapi_quota_reset_timestamp_seconds)";
          }
        ];
        transformations = [
          {
            id = "organize";
            options = {
              excludeByName.Time = true;
              renameByName = {
                account = "Konto";
                window = "Limit";
                Value = "Reset";
              };
            };
          }
        ];
        fieldConfig.overrides = [
          {
            matcher = {
              id = "byName";
              options = "Reset";
            };
            properties = [
              {
                id = "unit";
                value = "dateTimeAsIso";
              }
            ];
          }
        ];
      }
      (panel {
        id = 9;
        title = "Tokens pro Konto · letzte 5 Stunden";
        metric = "cliproxyapi_tokens_total";
        unit = "short";
        type = "bargauge";
        window = "5h";
        gridPos = {
          x = 0;
          y = 15;
          w = 12;
          h = 7;
        };
      })
      (panel {
        id = 10;
        title = "Tokens pro Konto · letzte 7 Tage";
        metric = "cliproxyapi_tokens_total";
        unit = "short";
        type = "bargauge";
        window = "7d";
        gridPos = {
          x = 12;
          y = 15;
          w = 12;
          h = 7;
        };
      })
      (panel {
        id = 1;
        title = "Tokens pro Konto · gewählter Zeitraum";
        metric = "cliproxyapi_tokens_total";
        unit = "short";
        type = "bargauge";
        gridPos = {
          x = 0;
          y = 22;
          w = 12;
          h = 7;
        };
      })
      (panel {
        id = 2;
        title = "Anfragen pro Konto · gewählter Zeitraum";
        metric = "cliproxyapi_requests_total";
        unit = "short";
        type = "bargauge";
        gridPos = {
          x = 12;
          y = 22;
          w = 12;
          h = 7;
        };
      })
      (panel {
        id = 3;
        title = "Tokenverbrauch im Zeitverlauf";
        metric = "cliproxyapi_tokens_total";
        unit = "short";
        type = "timeseries";
        gridPos = {
          x = 0;
          y = 29;
          w = 24;
          h = 10;
        };
      })
      (panel {
        id = 4;
        title = "Anfragen im Zeitverlauf";
        metric = "cliproxyapi_requests_total";
        unit = "short";
        type = "timeseries";
        gridPos = {
          x = 0;
          y = 39;
          w = 12;
          h = 9;
        };
      })
      {
        id = 14;
        title = "Gemeldete Claude-Zusatzausgaben";
        description = "Der von Anthropic gemeldete Zusatzverbrauch. Abo-Gebühren und API-Preis-Schätzungen sind nicht enthalten.";
        inherit datasource;
        type = "table";
        gridPos = {
          x = 0;
          y = 55;
          w = 24;
          h = 6;
        };
        targets = [
          {
            inherit datasource;
            refId = "A";
            instant = true;
            range = false;
            format = "table";
            expr = "max by (account, currency) (cliproxyapi_extra_spend)";
          }
        ];
        transformations = [
          {
            id = "organize";
            options = {
              excludeByName.Time = true;
              renameByName = {
                account = "Konto";
                currency = "Währung";
                Value = "Zusatzverbrauch";
              };
            };
          }
        ];
        fieldConfig.defaults.decimals = 2;
      }
      (panel {
        id = 11;
        title = "Eingabetokens pro Konto";
        metric = "cliproxyapi_input_tokens_total";
        unit = "short";
        type = "bargauge";
        gridPos = {
          x = 0;
          y = 48;
          w = 8;
          h = 7;
        };
      })
      (panel {
        id = 12;
        title = "Ausgabetokens pro Konto";
        metric = "cliproxyapi_output_tokens_total";
        unit = "short";
        type = "bargauge";
        gridPos = {
          x = 8;
          y = 48;
          w = 8;
          h = 7;
        };
      })
      (panel {
        id = 13;
        title = "Cache-Tokens pro Konto";
        metric = "cliproxyapi_cached_tokens_total";
        unit = "short";
        type = "bargauge";
        gridPos = {
          x = 16;
          y = 48;
          w = 8;
          h = 7;
        };
      })
      (panel {
        id = 5;
        title = "Fehlgeschlagene Anfragen im Zeitverlauf";
        metric = "cliproxyapi_failures_total";
        unit = "short";
        type = "timeseries";
        gridPos = {
          x = 12;
          y = 39;
          w = 12;
          h = 9;
        };
      })
    ];
  }
