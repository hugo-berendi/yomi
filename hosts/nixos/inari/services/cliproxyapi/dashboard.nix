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
          then "$__range"
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
      (panel {
        id = 1;
        title = "Tokens pro Konto · gewählter Zeitraum";
        metric = "cliproxyapi_tokens_total";
        unit = "short";
        type = "bargauge";
        gridPos = {
          x = 0;
          y = 0;
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
          y = 0;
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
          y = 7;
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
          y = 17;
          w = 12;
          h = 9;
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
          y = 17;
          w = 12;
          h = 9;
        };
      })
    ];
  }
