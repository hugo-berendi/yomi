BEGIN;
CREATE SCHEMA IF NOT EXISTS grafana_healthchecks;
REVOKE ALL ON SCHEMA grafana_healthchecks FROM PUBLIC;

CREATE OR REPLACE VIEW grafana_healthchecks.checks AS
SELECT name, tags, last_ping, alert_after,
       EXTRACT(EPOCH FROM last_duration) AS duration_seconds,
       CASE
           WHEN last_start + grace <= now() THEN 'down'
           WHEN last_start IS NOT NULL THEN 'started'
           WHEN status IN ('new', 'paused', 'down') THEN status
           WHEN alert_after <= now() THEN 'down'
           WHEN alert_after - grace <= now() THEN 'grace'
           ELSE 'up'
       END AS state
FROM public.api_check;

CREATE OR REPLACE VIEW grafana_healthchecks.pings AS
SELECT ping.created, check_row.name, ping.kind
FROM public.api_ping AS ping
JOIN public.api_check AS check_row ON check_row.id = ping.owner_id;

GRANT USAGE ON SCHEMA grafana_healthchecks TO grafana;
GRANT SELECT ON grafana_healthchecks.checks, grafana_healthchecks.pings TO grafana;
COMMIT;
