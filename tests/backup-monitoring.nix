{
  pkgs,
  rules,
}: let
  alerts = builtins.concatMap (group: group.rules) rules.groups;
  expression = uid: (builtins.head (builtins.filter (rule: rule.uid == uid) alerts)).data;
  query = uid: (builtins.head (expression uid)).model.expr;
  testFile = pkgs.writeText "backup-alert-tests.json" (builtins.toJSON {
    evaluation_interval = "1h";
    tests = [
      {
        name = "Down targets alert; laptop sleep does not";
        interval = "1m";
        input_series = [
          {
            series = ''up{job="inari-system",instance="server"}'';
            values = "0";
          }
          {
            series = ''up{job="amaterasu-backups",instance="laptop"}'';
            values = "0";
          }
        ];
        promql_expr_test = [
          {
            expr = query "inari-target-down";
            eval_time = "0m";
            exp_samples = [
              {
                labels = ''{job="inari-system",instance="server"}'';
                value = 1;
              }
            ];
          }
        ];
      }
      {
        name = "A timer firing cannot refresh the last successful backup";
        interval = "1h";
        input_series = [
          {
            series = ''yomi_restic_last_success_timestamp_seconds{host="inari",backup="offsite"}'';
            values = "1+0x50";
          }
        ];
        promql_expr_test = [
          {
            expr = query "inari-offsite-stale";
            eval_time = "1h";
            exp_samples = [
              {
                labels = "{}";
                value = 0;
              }
            ];
          }
          {
            expr = query "inari-offsite-stale";
            eval_time = "31h";
            exp_samples = [
              {
                labels = "{}";
                value = 1;
              }
            ];
          }
        ];
      }
      {
        name = "Missing success metrics alert";
        interval = "1h";
        input_series = [];
        promql_expr_test = [
          {
            expr = query "inari-offsite-stale";
            eval_time = "1h";
            exp_samples = [
              {
                labels = ''{host="inari",backup="offsite"}'';
                value = 1;
              }
            ];
          }
        ];
      }
      {
        name = "An offline laptop gets seven days, then alerts";
        interval = "1h";
        input_series = [
          {
            series = ''yomi_restic_last_success_timestamp_seconds{host="amaterasu",backup="data"}'';
            values = "1 stale _x192";
          }
        ];
        promql_expr_test = [
          {
            expr = query "amaterasu-data-stale";
            eval_time = "24h";
            exp_samples = [
              {
                labels = "{}";
                value = 0;
              }
            ];
          }
          {
            expr = query "amaterasu-data-stale";
            eval_time = "169h";
            exp_samples = [
              {
                labels = "{}";
                value = 1;
              }
            ];
          }
        ];
      }
    ];
  });
in
  pkgs.runCommand "backup-monitoring-tests" {nativeBuildInputs = [pkgs.prometheus.cli pkgs.nodejs];} ''
    promtool test rules ${testFile}
    node ${./backup-report.cjs} ${../hosts/nixos/inari/services/n8n/workflows/backup-storage.json}
    touch "$out"
  ''
