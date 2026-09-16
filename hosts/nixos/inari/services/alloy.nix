{config, ...}: {
  # {{{ Service
  # Ships the systemd journal (all units) to Loki so logs are actually
  # queryable from Grafana instead of only living in `journalctl`.
  # promtail is end-of-life upstream; Grafana Alloy is its replacement.
  services.alloy.enable = true;

  environment.etc."alloy/config.alloy".text = ''
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }

      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }

    loki.source.journal "read" {
      forward_to    = [loki.write.default.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels = {
        job  = "systemd-journal",
        host = "inari",
      }
    }

    loki.write "default" {
      endpoint {
        url = "http://127.0.0.1:${toString config.yomi.ports.loki}/loki/api/v1/push"
      }
    }
  '';
  # }}}
}
