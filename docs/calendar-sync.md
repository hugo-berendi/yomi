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

## Recurring update compatibility

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

A live probe on 2026-09-30 isolated the incompatible property using temporary
events with separate UIDs. All updates used freshly fetched DAV ETags:

| Update | Google response |
| ------ | --------------- |
| Unchanged recurring event, ordinary event edit, recurring master edit | 204 |
| One exception with its own sequence, four exceptions with mixed sequences | 409 |
| Four exceptions with the master's sequence | 204, all four retained |
| Four exceptions without explicit sequences | 204, all four retained |

All seven test events were deleted and the original timer and path trigger
resumed. The rejected requests returned only an empty DAV error element.
Fresh ETags did not resolve the mixed-sequence case.

Inari's vdirsyncer package carries a
[Google-specific patch](../hosts/nixos/inari/services/radicale/google-recurrence-sequence.patch)
that omits `SEQUENCE` from detached exception components in outgoing writes.
The master revision stays intact. Google assigns the exception revision.
The conversion creates a new in-memory item, preserving the source item and its
sync hash. Dates, descriptions, folded properties, timezones and
alarms stay intact. Ordinary CalDAV writes are unaffected, and the normal
`If-Match` and `If-None-Match` checks remain in place.

The patched client subsequently passed all seven live write cases, retaining
every exception. Its successful PUT responses still omitted ETags. Vdirsyncer
therefore fetches Google's representation again on the next sync. The existing
bidirectional sync can copy Google's assigned revision counters and normalized
metadata back to Radicale. The outgoing conversion preserves the caller's item;
it does not promise that later bidirectional syncs preserve its byte formatting
or independent exception counters.

A full sync rehearsal retained all four exceptions, and its subsequent unchanged
sync made no further Google writes. That sync changed the isolated local fixture's
bytes. A follow-up content comparison on 2026-10-01 passed with no event content
differences. Dates, recurrence, descriptions and the other event properties
survived the round trip. The comparison allows Google's revision counters,
timestamps, calendar labels, equivalent timezone serialization and empty default
properties; it still detects changes to descriptions, dates, recurrence, titles
and cancellation status. All temporary events were deleted, no cleanup remained
pending, and the original timer and path trigger resumed.

The `calendar-sync` flake check exercises uploads and repeated updates through
the packaged Google storage client. It rejects the original mixed-sequence
payload, then checks the compatible payload, source preservation and DAV
preconditions. Keep this check when updating vdirsyncer; remove the local patch
only after the packaged client passes the same regression and live probe.

Deploying this package requires the operator's normal switch. A manual
`vdirsyncer-google sync radicale_google/scouts` after deployment retries the
existing pending edit. Verify the exceptions on both sides and a subsequent
unchanged sync before considering the live event repaired. There is no need to
delete the series or reset sync state.
