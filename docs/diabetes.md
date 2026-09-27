# Diabetes journal on Yomi

The journal compares complete Monday–Sunday weeks in Europe/Berlin. It runs on
Inari at `https://diabetes.hugo-berendi.de`, through the existing tailnet nginx
endpoint. There is no Cloudflare tunnel or new firewall grant. Raw Glooko uploads
stay in memory; the database retains normalized CGM/delivered-bolus records,
notes, appointments, supply counts and calculated reports. No treatment settings
are written to Dexcom or Omnipod.

## First use after a human switches the configuration

1. Retrieve `/var/lib/diabetes/access-token` with interactive sudo on Inari and
   save it in your password manager. Do not paste it into chat or commit it.
   Open the journal over HTTPS and log in with that key.
2. In Glooko's web app, export 30 days as CSV ZIP. Upload it under **Import a
   Glooko export**, checking the date order and timezone against the export.
   The journal rejects ambiguous Berlin clock-change timestamps without offsets.
3. Review the imported count, unsupported-file notice, date boundaries and
   glucose graphs against Glooko before relying on the report. No real export
   was available during implementation; unsupported regional headers must be
   mapped explicitly, rather than guessed by column position.
4. Confirm analysis ranges and display units in Settings. Defaults are 70–180
   mg/dL for retrospective analysis, not a prescription or a pump target.
5. Enter your actual stock, usual replacement intervals and delivery lead times.
   Confirm a Pod/sensor change only after it happens. Submitting the same form
   twice is idempotent. Use the stock form to correct counts after deliveries.

The service creates an access key, a separate read-only glucose key and a session
signing key on first startup, mode 0600. The directory is mode 0700 and owned by
`diabetes`. They are runtime secrets, never Nix-store values. The pre-existing
Home Assistant token is passed using systemd LoadCredential from sops-nix.

## Report methodology

Each CGM reading covers the following interval, capped at five minutes and the
next reading. Missing time is not filled. Coverage uses the actual duration of
the Berlin week, including 167/169-hour daylight-saving weeks. Range percentages,
mean and coefficient of variation are time-weighted over observed intervals.
The boundaries count as in range. Night is 00:00–06:00 Berlin time.

High episodes require 15 consecutive observed minutes above the upper analysis
boundary. A missing interval ends an episode. Total high time includes shorter
excursions too. Episode counts, duration and recorded bolus counts depend on
coverage; they are not comparable exposure-adjusted rates. Week-to-week changes
in percentages are percentage points. The report limits interpretation if either
week has less than 70% coverage; this is an application completeness gate, not
a claim of statistical or clinical significance.

Reports include four weeks of context and up to five longest high episodes with
bolus records during their first hour. There is no reliable meal timestamp in a
carb entry. These associations cannot establish forgotten/late boluses. Insulin
delivery, meal timing, exercise and illness need clinical context.

Supported UTF-8 export families:

- `cgm*.csv`: `Timestamp` plus `Glucose (mg/dL)` or `Glucose (mmol/L)`;
  `Glucose Value (...)` is also recognized.
- `bolus*.csv`: `Timestamp` plus `Insulin Delivered (U)`,
  `Bolus Volume Delivered (U)` or `Insulin (U)`. Optional `Carbs (g)`,
  `Carbs Input (g)` or `Carbohydrates (g)`.
- A standalone normalized CSV may use the same columns plus `Type` explicitly
  set to `cgm` or `bolus`. Metadata lines before the header are supported.
- ISO 8601, German dotted dates, and explicitly selected day/month or month/day
  slash dates with a time. Offsets override the selected timestamp timezone.

Unknown CSVs are reported and skipped. Recognized malformed rows abort the entire
import. Overlapping exports deduplicate by kind and exact timestamp. Conflicting
values at the same timestamp abort the transaction, including different boluses
at the same timestamp; select one export source or extend the importer with an
explicit event identifier before importing such data. BG fingersticks, basal,
alarms and manually logged events are not interpreted as CGM or boluses.

## Local AI

The existing loopback 3B llama.cpp classifier selects up to three calculated statements
and two prepared appointment questions. Only allowlisted IDs are accepted.
There is no free-form medical generation, numerical rewriting or dosing advice.
No names, free-text notes, raw traces or cloud requests enter the AI call.
AI can be disabled in Settings; failure leaves the deterministic report intact.
On Inari, three synthetic comparisons produced valid selections in 62–65 seconds
on the 3B model. The 14B request timed out after 180 seconds. These checks validate
the output contract, not clinical reasoning.
Attempts are capped at one per hour with a 180-second request timeout. Unchanged
reports reuse the selection. A changed import invalidates it.

## Phone and Galaxy Watch7

Install/sign in to the Home Assistant Android companion app on the S25+ and
enable that app's notifications for the Watch7 in Galaxy Wearable. Find the
phone's `notify.mobile_app_...` action in Home Assistant Developer Tools. In the
journal Settings enter only `mobile_app_...`. The service deliberately does not
choose an existing family member's phone or the `all_devices` group.

The five-minute background job sends generic notifications for a weekly report
or missing upload, due replacements, low stock, appointment preparation and
manually started meal checks. Health values never appear in these notifications.
Delivery is retried on failure. Stable tags replace duplicates if a crash occurs
after the send and before acknowledgement is stored. Reorder notices remain
suppressed until the stock count increases after a delivery. Meal checks expire
after two hours; snooze is five minutes, not advice about insulin timing.

Sustained-high prompts and optional dim bedside lighting start disabled. Enable
them only after setting the analysis boundaries, phone/light entities and live
Dexcom connection. They supplement native Dexcom alerts. The high reminder needs
fresh consecutive readings, with no gap over six minutes, above the configured
boundary for the selected duration. It repeats only after the episode resets.
The light acts below the lower boundary between 22:00 and 06:00, at most hourly.
No glucose rise is labelled a missed dose.

## Live Dexcom Share and Waybar

Enable Dexcom Share in the G7 app with at least one follower. Provision an
encrypted sops secret containing JSON with `username` and `password`, then set:

```nix
sops.secrets.diabetes_dexcom.sopsFile = ../secrets.yaml;
yomi.diabetes.dexcomCredentialFile = config.sops.secrets.diabetes_dexcom.path;
```

The reader uses the outside-US Share region and the original CGM reading
timestamp, not Home Assistant's state-change timestamp. Reads are serialized
and cached for a minute within the web process. A reading older than ten minutes
or more than a minute into the future is unavailable. No credential is required
for reports and supplies. Home Assistant's Dexcom component is also included;
its own account setup remains a UI config flow if you want native HA dashboards.

For amaterasu, securely copy `/var/lib/diabetes/read-token` into a private,
file at `~/.config/yomi-diabetes/read-token`. The directory is included in Home
Manager persistence. Create `~/.config/yomi-diabetes/config.json`:

```json
{
  "url": "https://diabetes.hugo-berendi.de",
  "tokenFile": "~/.config/yomi-diabetes/read-token"
}
```

Set the directory to mode 0700 and both files to mode 0600.
The read token only permits `GET /api/glucose`, not reports or writes.
Waybar stays hidden until configured, shows unavailable when data is stale, and
opens `/live` on click. The browser requires the full journal login separately.
The previous unused standalone Dexcom script is not used by this integration.

## n8n and scheduling

`diabetes-jobs.timer` runs every five minutes and catches up after downtime.
Weekly reports are keyed by their Monday date. Fresh imports regenerate the
current comparison; prior weekly snapshots remain browsable.
The weekly notification becomes due on Monday at 08:00 Berlin time, with catch-up
after that time if the service was offline.

The optional **Diabetes · Weekly comparison** n8n workflow is seeded inactive
with `enforce = false`. The timer works without it. Attach an HTTP Header Auth
credential with name `Authorization` and value `Bearer <access-token>` in n8n,
test the workflow, then activate it if desired. It runs Monday 08:00 Berlin time
and calls the same locked job. It stores neither successful nor failed execution
payloads. Follow the n8n AGENTS.md export procedure before enforcing its real
credential ID. No credentials are embedded in the JSON.

## Persistence, backup and validation

`/var/lib/diabetes` persists under `/persist/state/var/lib/diabetes`, included in
the existing local state backup and explicitly in the encrypted off-site set.
Each completed background job atomically publishes `backup.sqlite` through
SQLite's backup API. Restore that consistent snapshot as `journal.sqlite` after
stopping both diabetes units; do not restore a live database and its journal
from different instants. The snapshot can lag recent edits by five minutes.
Access keys are included: rotate them after a restore if their confidentiality
is uncertain. Raw source exports remain your responsibility because the importer
does not save them.

Run the synthetic regression suite with the same Python dependencies as the
service. It covers DST, gaps, range boundaries, duplicate/conflicting imports,
CSRF, read-token scope, retries, stock updates, chart rendering and stale glucose.
`just diabetes-test` builds that Python environment from the pinned flake.

On deployment, expect the new diabetes service/timer, nginx configuration,
Home Assistant component environment, n8n import/environment, and off-site restic
unit to change. A separate amaterasu switch updates Waybar. Do not switch Inari
from an unattended agent session. No live notifications or account connections
were tested without your device setup and credentials.
