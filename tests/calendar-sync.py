"""Exercise the packaged Google client's write path with synthetic events."""

import asyncio
from types import SimpleNamespace
import sys
from unittest.mock import AsyncMock
from urllib.parse import urljoin

sys.path.insert(0, sys.argv[1])

import aiohttp  # noqa: E402
from vdirsyncer.storage.dav import CalDAVStorage  # noqa: E402
from vdirsyncer.storage.google import GoogleCalendarStorage  # noqa: E402
from vdirsyncer.vobject import Item  # noqa: E402


def fixture():
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VTIMEZONE",
        "TZID:Europe/Berlin",
        "BEGIN:STANDARD",
        "DTSTART:19701025T030000",
        "TZOFFSETFROM:+0200",
        "TZOFFSETTO:+0100",
        "END:STANDARD",
        "END:VTIMEZONE",
    ]
    for index, sequence in enumerate([4, 1, 1, 2, 1]):
        date = ["20260929", "20261006", "20261013", "20261020", "20261027"][index]
        lines += [
            "BEGIN:VEVENT",
            "UID:synthetic-recurring-event",
            "SUMMARY:Test ",
            " with a folded summary",
            f"DTSTART;TZID=Europe/Berlin:{date}T173000",
            f"DTEND;TZID=Europe/Berlin:{date}T193000",
            "DTSTAMP:20260929T173310Z",
            f"SEQUENCE:{sequence}",
        ]
        if index:
            lines += [
                f"RECURRENCE-ID;TZID=Europe/Berlin:{date}T173000",
                f"DESCRIPTION:Private exception {index}\\nSecond line",
            ]
        else:
            lines += ["RRULE:FREQ=WEEKLY;WKST=MO;INTERVAL=1;BYDAY=TU"]
        lines += [
            "BEGIN:VALARM",
            "ACTION:DISPLAY",
            "TRIGGER:-PT10M",
            "DESCRIPTION:Private reminder",
            "END:VALARM",
            "END:VEVENT",
        ]
    return Item("\r\n".join(lines + ["END:VCALENDAR", ""]))


class RecordingSession:
    url = "https://calendar.invalid/events/"

    def __init__(self, google):
        self.google = google
        self.requests = []

    def get_default_headers(self):
        return {}

    async def request(self, method, href, *, data, headers):
        self.requests.append((method, href, data, headers.copy()))
        parsed = Item(data.decode()).parsed
        events = [c for c in parsed.subcomponents if c.name == "VEVENT"]
        masters = [c for c in events if "RECURRENCE-ID" not in c]
        if self.google and len(masters) == 1:
            master_sequence = masters[0].get("SEQUENCE", "0")
            if any(
                "RECURRENCE-ID" in c
                and c.get("SEQUENCE", master_sequence) != master_sequence
                for c in events
            ):
                # Reproduced against Google with a fresh ETag on 2026-09-30.
                raise aiohttp.ClientResponseError(
                    SimpleNamespace(real_url=self.url), (), status=409
                )
        return SimpleNamespace(
            status=204,
            headers={"etag": '"synthetic-google-v2"'},
            content=SimpleNamespace(read=AsyncMock(return_value=b"")),
            url=urljoin(self.url, href),
        )


def without_instance_sequences(parsed):
    for component in parsed.subcomponents:
        if component.name == "VEVENT" and "RECURRENCE-ID" in component:
            del component["SEQUENCE"]
    return parsed


async def main():
    original = fixture()
    original_raw = original.raw
    original_hash = original.hash
    async with aiohttp.TCPConnector() as connector:
        google = GoogleCalendarStorage(
            collection="synthetic",
            url=RecordingSession.url,
            token_file="/unused-test-token",
            client_id="synthetic-id",
            client_secret="synthetic-secret",
            connector=connector,
        )
        google.session = RecordingSession(google=True)
        for operation in ("upload", "update", "update"):
            if operation == "upload":
                await google.upload(original)
            else:
                await google.update("/events/synthetic.ics", original, '"fresh-etag"')
            method, _, data, headers = google.session.requests[-1]
            assert method == "PUT"
            sent = Item(data.decode())
            assert without_instance_sequences(
                sent.parsed
            ) == without_instance_sequences(original.parsed), (
                "Google's outgoing conversion changed event content"
            )
            assert original.raw == original_raw and original.hash == original_hash, (
                "Converting Google's copy changed the source event or its sync hash"
            )
            if operation == "upload":
                assert headers["If-None-Match"] == "*"
            else:
                assert headers["If-Match"] == '"fresh-etag"', (
                    "The workaround bypassed DAV concurrency protection"
                )

        assert len({request[2] for request in google.session.requests}) == 1, (
            "Repeated conversion should produce the same outgoing bytes"
        )

        plain = CalDAVStorage(url=RecordingSession.url, connector=connector)
        plain.session = RecordingSession(google=False)
        await plain.update("/events/synthetic.ics", original, '"fresh-etag"')
        assert plain.session.requests[-1][2] == original_raw.encode(), (
            "The Google workaround changed ordinary CalDAV writes"
        )

        master_only = original.parsed
        master_only.subcomponents = [
            c
            for c in master_only.subcomponents
            if c.name != "VEVENT" or "RECURRENCE-ID" not in c
        ]
        single = Item("\r\n".join(master_only.dump_lines()))
        await google.update("/events/single.ics", single, '"fresh-etag"')
        assert google.session.requests[-1][2] == single.raw.encode(), (
            "A master without exceptions should pass through byte-for-byte"
        )


asyncio.run(main())
