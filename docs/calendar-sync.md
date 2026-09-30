# Calendar sync

Inari syncs nine explicitly mapped Radicale collections with Google Calendar.
The mapping and service configuration live in
[`radicale.nix`](../hosts/nixos/inari/services/radicale.nix).
Each Google calendar must already exist before adding its mapping.

The timer runs every five minutes. Radicale also touches a trigger file after a
storage change, which activates `vdirsyncer@radicale_google.path`. The service
syncs collections sequentially because simultaneous writes previously triggered
Google HTTP 403 responses. A failed collection does not stop the remaining ones,
but the service returns failure so that the problem remains visible.

`conflict_resolution = "a wins"` prefers Radicale when both sides have conflicting
changes. Sync is still bidirectional. This setting does not disable imports of
Google edits or deletions, and it does not override Google's HTTP preconditions.

## Inspecting failures

On inari, these commands do not require sudo:

```console
journalctl -u vdirsyncer@radicale_google.service -n 100 --no-pager
systemctl status vdirsyncer@radicale_google.service
systemctl list-timers vdirsyncer@radicale_google.timer
```

A manual sync uses the installed configuration and the `calendar-sync` account.
It can write to both calendars and needs interactive sudo:

```console
vdirsyncer-google sync radicale_google/scouts
```

The sync state and OAuth token are under `/var/lib/vdirsyncer/radicale_google`.
Radicale's event files are under `/persist/data/radicale/collection-root`.
Both locations have restricted access. Keep diagnostics limited to the failing
UID and collection. Event text, passwords and OAuth tokens should not appear in
shared reports. Vdirsyncer's debug logs include request headers and event bodies,
so a raw debug log is unsuitable for sharing.

## Recurring update failure investigated on 2026-09-30

The running vdirsyncer 0.20.0 repeatedly received HTTP 409 while updating one
recurring event in the scouts collection. Other collections completed.
A read-only comparison established:

- Radicale held a master at `SEQUENCE:4` and four exception components. The
  exceptions had sequences 1, 1, 2 and 1.
- Google's CalDAV representation held only the original master at `SEQUENCE:0`.
  The four exceptions had not reached Google.
- The master schedule and recurrence rule matched. Neither representation had
  an organizer or attendees, and neither calendar object had a `METHOD`.
- Google returned the event successfully but supplied no ETag on that GET.
  Comparing an absent GET ETag with the saved sync ETag cannot establish that
  the saved state is stale. The sync client obtains ETags through DAV reports.

Reading expanded occurrences from the Google Calendar connector confirms their
dates but does not prove that the edited exception components were imported.
The same symptom is reported in upstream
[vdirsyncer issue 963](https://github.com/pimutils/vdirsyncer/issues/963).
That similarity does not establish the cause of this event's failure.

The exact rejection remains unresolved. A useful live reproduction must compare
ordinary event updates, recurring master updates and exception updates using
fresh DAV ETags. Test resources should have separate UIDs and be removed before
resuming the timer and path trigger. Resetting all sync state or deleting the
real series would lose diagnostic evidence and can propagate deletions.
