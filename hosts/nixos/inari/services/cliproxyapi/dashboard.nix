# Grafana lays panels out by y, then x, and stacks them full width on a phone.
# Each limit window is one table with a line per account (share used, reset
# in local time), so the phone needs no horizontal scrolling; the rarely read
# details sit in a collapsed row at the end.
{pkgs}: let
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };
  pos = x: y: w: h: {inherit x y w h;};
  target = expr: extra:
    {
      inherit datasource expr;
      refId = "A";
      legendFormat = "{{account}}";
    }
    // extra;
  instant = expr:
    target expr {
      instant = true;
      range = false;
    };
  row = title: y: collapsed: panels: {
    inherit title collapsed panels;
    type = "row";
    gridPos = pos 0 y 24 1;
  };
  # Name above the bar, the full width for the bar, the value at its end:
  # the layout that keeps long account names readable on a phone.
  bars = {
    title,
    description,
    gridPos,
    expr,
    defaults,
  }: {
    inherit title description datasource gridPos;
    type = "bargauge";
    targets = [(instant expr)];
    fieldConfig.defaults = {noValue = "–";} // defaults;
    options = {
      orientation = "horizontal";
      displayMode = "basic";
      namePlacement = "top";
      valueMode = "color";
      showUnfilled = true;
      sizing = "manual";
      minVizHeight = 26;
      maxVizHeight = 30;
      reduceOptions.calcs = ["lastNotNull"];
    };
  };
  tokens = metric: window: title: gridPos:
    bars {
      inherit title gridPos;
      description = "Nur über CLIProxyAPI erfasste Nutzung. Direkte Nutzung beim Anbieter fehlt.";
      expr = "sort_desc(sum by (account) (increase(${metric}[${window}])))";
      defaults = {
        unit = "short";
        min = 0;
        color.mode = "palette-classic-by-name";
      };
    };
  # One table per limit window: account, a gauge cell for the share used and
  # the reset in local clock time, so each account reads as one line, also on
  # a phone. The fullest account comes first.
  limits = window: title: format: x: {
    inherit title datasource;
    description = "Vom Anbieter gemeldete Auslastung und Reset-Zeit in Ortszeit. Ein Konto fehlt, wenn der Anbieter dafür kein aktuelles Fenster meldet.";
    type = "table";
    gridPos = pos x 1 12 8;
    targets = [
      ((instant ''max by (account) (cliproxyapi_quota_used_percent{window="${window}"})'') // {format = "table";})
      ((instant ''max by (account) (1000 * cliproxyapi_quota_reset_timestamp_seconds{window="${window}"})'')
        // {
          format = "table";
          refId = "B";
        })
    ];
    transformations = [
      {
        id = "merge";
        options = {};
      }
      {
        id = "organize";
        options = {
          excludeByName.Time = true;
          renameByName = {
            account = "Konto";
            "Value #A" = "Auslastung";
            "Value #B" = "Reset";
          };
        };
      }
      {
        id = "sortBy";
        options.sort = [
          {
            field = "Auslastung";
            desc = true;
          }
        ];
      }
    ];
    fieldConfig = {
      defaults.custom = {
        align = "auto";
        cellOptions.type = "auto";
      };
      overrides = [
        {
          # Long account names wrap instead of pushing the reset column off a
          # phone screen.
          matcher = {
            id = "byName";
            options = "Konto";
          };
          properties = [
            {
              id = "custom.wrapText";
              value = true;
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "Auslastung";
          };
          properties = [
            {
              id = "unit";
              value = "percent";
            }
            {
              id = "decimals";
              value = 0;
            }
            {
              id = "min";
              value = 0;
            }
            {
              id = "max";
              value = 100;
            }
            {
              id = "custom.width";
              value = 88;
            }
            {
              id = "custom.cellOptions";
              value = {
                type = "gauge";
                mode = "basic";
                valueDisplayMode = "text";
              };
            }
            {
              id = "thresholds";
              value = {
                mode = "absolute";
                steps = [
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
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "Reset";
          };
          properties = [
            {
              id = "unit";
              value = "time:${format}";
            }
            {
              id = "custom.align";
              value = "right";
            }
            {
              id = "custom.width";
              value =
                if format == "HH:mm"
                then 52
                else 104;
            }
          ];
        }
      ];
    };
    options = {
      showHeader = true;
      cellHeight = "md";
      footer.show = false;
    };
  };
  # Details depend on the dashboard's time range.
  timeseries = metric: title: gridPos: {
    inherit title datasource gridPos;
    type = "timeseries";
    targets = [(target "sum by (account) (increase(${metric}[$__rate_interval]))" {})];
    fieldConfig.defaults = {
      unit = "short";
      min = 0;
      color.mode = "palette-classic-by-name";
      custom = {
        fillOpacity = 10;
        showPoints = "never";
      };
    };
    options = {
      legend = {
        displayMode = "list";
        placement = "bottom";
      };
      tooltip.mode = "multi";
    };
  };
  details = [
    (timeseries "cliproxyapi_tokens_total" "Tokens im Zeitverlauf" (pos 0 15 24 9))
    (tokens "cliproxyapi_input_tokens_total" "$__range" "Eingabetokens · Zeitraum" (pos 0 24 8 7))
    (tokens "cliproxyapi_output_tokens_total" "$__range" "Ausgabetokens · Zeitraum" (pos 8 24 8 7))
    (tokens "cliproxyapi_cached_tokens_total" "$__range" "Cache-Tokens · Zeitraum" (pos 16 24 8 7))
    (tokens "cliproxyapi_requests_total" "$__range" "Anfragen · Zeitraum" (pos 0 31 12 7))
    (timeseries "cliproxyapi_failures_total" "Fehlgeschlagene Anfragen" (pos 12 31 12 7))
    {
      title = "Claude-Zusatzausgaben";
      description = "Der von Anthropic gemeldete Zusatzverbrauch. Abo-Gebühren und API-Preis-Schätzungen sind nicht enthalten.";
      inherit datasource;
      type = "stat";
      gridPos = pos 0 38 24 5;
      targets = [
        (target "max by (account, currency) (cliproxyapi_extra_spend)" {
          instant = true;
          range = false;
          legendFormat = "{{account}} ({{currency}})";
        })
      ];
      fieldConfig.defaults = {
        decimals = 2;
        noValue = "Nichts gemeldet";
        color = {
          mode = "fixed";
          fixedColor = "text";
        };
      };
      options = {
        orientation = "horizontal";
        textMode = "value_and_name";
        wideLayout = true;
        colorMode = "none";
        graphMode = "none";
        reduceOptions.calcs = ["lastNotNull"];
      };
    }
  ];
  panels = [
    (row "Abo-Limits" 0 false [])
    (limits "5h" "5 Stunden" "HH:mm" 0)
    (limits "7d" "Woche" "DD.MM. HH:mm" 12)
    (row "Verbrauch über den Proxy" 9 false [])
    (tokens "cliproxyapi_tokens_total" "5h" "Tokens · letzte 5 Stunden" (pos 0 10 12 6))
    (tokens "cliproxyapi_tokens_total" "7d" "Tokens · letzte 7 Tage" (pos 12 10 12 6))
    (row "Details" 16 true details)
  ];
  # Provisioned dashboards need ids unique across nested rows too.
  number = start: list: pkgs.lib.imap0 (i: p: p // {id = start + i;}) list;
in
  (pkgs.formats.json {}).generate "cliproxyapi-usage.json" {
    uid = "cliproxyapi-usage";
    title = "CLIProxyAPI · Kontoverbrauch";
    tags = ["CLIProxyAPI"];
    schemaVersion = 39;
    refresh = "1m";
    time = {
      from = "now-24h";
      to = "now";
    };
    panels = map (p:
      if p.type == "row"
      then p // {panels = number 100 p.panels;}
      else p) (number 1 panels);
  }
