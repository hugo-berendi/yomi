"""List the new releases of the library's artists, for a Release Radar.

Takes every artist in beets' library, looks each up on Deezer's public API,
and lists what they released in the week up to today, Saturday to Friday as
Spotify's does: every song of a single or EP, and the PER_ALBUM most played
songs of an album, at most PER_ARTIST songs of one artist and LIMIT in all.
Artists with more songs in the library come first, and each one's newest
release. The list is a CSV sockseek downloads like a playlist.

Every artist, not only the most collected: on 2026-11-20 the 36 with three
songs or more had released 2 songs that week, both too new for Soulseek,
while artists with one or two songs had released Spotify's picks, such as
REEZA's "Diva" and Zartmann's "Bad Düren". A lookup is cached, so after the
first run this costs one request per artist a week.

A release date alone does not make a song new. Deezer lists "Berq -
Complete", out 2026-11-06, as an album, not a compilation, and most of it
dates from 2023. So a song also needs an ISRC from this year (or last
year's, early in the year): the code is assigned once, when a recording is
first released, and keeps its year on every reissue. A song already in the
library is left out as well.

Deezer, not Spotify: Spotify's API gives development apps no new releases
since February 2026, and every request counts against the limit sockseek
needs. beets already asks Deezer for metadata.

An artist's name alone is not enough: there are many "Paul"s. Of the
Deezer artists with exactly that name, the one taken has an album or song
title in common with the library. Failing that, it is the only one of that
name with FAMOUS_FANS fans or more: the library often holds just a feature,
such as Eminem on Dr. Dre's "Forgot About Dre", which is on neither
artist's own albums nor top songs. Without either the artist is skipped. A
choice is kept in CACHE, so this happens once per artist; an artist not
found is looked up again the next week.

Usage: spotify-sync-radar LIBRARY_DB OUT_CSV CACHE_JSON
"""

from __future__ import annotations

import collections
import csv
import datetime
import json
import os
import re
import sqlite3
import sys
import tempfile
import time
import urllib.parse
import urllib.request

WINDOW_DAYS = 7
# How early in a year a song may still carry last year's ISRC.
ISRC_GRACE_DAYS = 90
PER_ALBUM = 3
PER_ARTIST = 3
LIMIT = 50
FAMOUS_FANS = 50_000
API = "https://api.deezer.com"

# As in spotify-sync-mixes.py: how Navidrome and beets name artists.
ARTIST_SPLIT = re.compile(r" / | feat\. | feat | ft\. | ft |; ")
CREDIT_SPLIT = re.compile(r", | & | x ")
BEETS_LIST = "\\␀"


def key(text: str) -> str:
    return "".join(c for c in text.casefold() if c.isalnum())


def split_names(text: str | None, pattern: re.Pattern) -> list[str]:
    return [n.strip() for n in pattern.split(text or "") if n.strip()]


Library = tuple[collections.Counter, dict[str, set[str]], set[tuple[str, str]]]


def library(db: str) -> Library:
    """Songs per artist, the keys of each artist's album and song titles, and
    (artist, title) keys of every song."""
    songs: collections.Counter[str] = collections.Counter()
    titles: dict[str, set[str]] = collections.defaultdict(set)
    have: set[tuple[str, str]] = set()
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=60)
    try:
        rows = con.execute("SELECT artist, artists, album, title FROM items").fetchall()
    finally:
        con.close()
    for artist, artists, album, title in rows:
        names = [n for n in (artists or "").split(BEETS_LIST) if n.strip()]
        names = names or split_names(artist, ARTIST_SPLIT)
        parts = {p for n in names for p in (split_names(n, CREDIT_SPLIT) or [n])}
        for part in parts:
            songs[part] += 1
            titles[part].update(k for k in (key(album or ""), key(title or "")) if k)
            have.add((key(part), key(title or "")))
    return songs, titles, have


def get(path: str, **params) -> dict:
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    for attempt in range(3):
        # Deezer allows 50 requests in 5 seconds.
        time.sleep(0.2)
        request = urllib.request.Request(
            url, headers={"User-Agent": "spotify-sync-radar"}
        )
        with urllib.request.urlopen(request, timeout=20) as response:
            body = json.load(response)
        error = body.get("error") if isinstance(body, dict) else None
        if not error:
            return body
        if error.get("code") != 4:  # 4: quota exceeded
            raise RuntimeError(f"Deezer: {error.get('message')}")
        time.sleep(5 * (attempt + 1))
    raise RuntimeError("Deezer: quota exceeded")


def find_artist(name: str, known: set[str]) -> int | None:
    """The Deezer artist of this name who shares a title with the library."""
    found = get("search/artist", q=name, limit=10).get("data", [])
    named = [c for c in found if key(c["name"]) == key(name)]
    for candidate in named:
        albums = get(f"artist/{candidate['id']}/albums", limit=100).get("data", [])
        tops = get(f"artist/{candidate['id']}/top", limit=50).get("data", [])
        theirs = {key(a["title"]) for a in albums} | {key(t["title"]) for t in tops}
        if theirs & known:
            return candidate["id"]
    famous = [c for c in named if c.get("nb_fan", 0) >= FAMOUS_FANS]
    return famous[0]["id"] if len(famous) == 1 else None


def releases(artist_id: int, since: datetime.date, today: datetime.date) -> list[dict]:
    albums = get(f"artist/{artist_id}/albums", limit=50).get("data", [])
    fresh = []
    for album in albums:
        try:
            released = datetime.date.fromisoformat(album.get("release_date", ""))
        except ValueError:
            continue
        # Deezer's own compilations; reissues under other names are caught by
        # the ISRC.
        if album.get("record_type") == "compile":
            continue
        if since <= released <= today:
            fresh.append({**album, "released": released})
    return fresh


def is_new(track: dict, today: datetime.date) -> bool:
    """Whether the song was first released this year, by its ISRC."""
    isrc = get(f"track/{track['id']}").get("isrc") or ""
    # CC-XXX-YY-NNNNN; without one there is nothing to go on.
    if len(isrc) != 12 or not isrc[5:7].isdigit():
        return True
    earliest = today - datetime.timedelta(days=ISRC_GRACE_DAYS)
    return 2000 + int(isrc[5:7]) >= earliest.year


def songs_of(
    album: dict, have: set[tuple[str, str]], today: datetime.date
) -> list[dict]:
    tracks = get(f"album/{album['id']}/tracks", limit=100).get("data", [])
    tracks = [
        t
        for t in tracks
        if (key(t["artist"]["name"]), key(t["title"])) not in have and is_new(t, today)
    ]
    if album.get("record_type") == "album":
        tracks = sorted(tracks, key=lambda t: -t.get("rank", 0))[:PER_ALBUM]
    return tracks


def main() -> None:
    db, out, cache_path = sys.argv[1:]
    try:
        with open(cache_path, encoding="utf-8") as f:
            cache: dict[str, int | None] = json.load(f)
    except FileNotFoundError:
        cache = {}

    counts, titles, have = library(db)
    today = datetime.date.today()
    since = today - datetime.timedelta(days=WINDOW_DAYS - 1)
    # Each release once, with the most collected of the artists it came up
    # for: a joint single of two library artists is listed under the bigger.
    found: dict[int, tuple[int, str, dict]] = {}
    missing = 0
    for name, n in counts.most_common():
        if cache.get(name) is None:
            cache[name] = find_artist(name, titles[name])
            missing += cache[name] is None
        if cache[name] is not None:
            for album in releases(cache[name], since, today):
                if album["id"] not in found or found[album["id"]][0] < n:
                    found[album["id"]] = (n, name, album)
    print(f"Release Radar: {missing} artists not found on Deezer", file=sys.stderr)

    rows = []
    seen = set()
    per_artist: collections.Counter[str] = collections.Counter()
    for _count, name, album in sorted(
        found.values(), key=lambda f: (f[0], f[2]["released"], f[2]["id"]), reverse=True
    ):
        if per_artist[name] >= PER_ARTIST:
            continue
        for track in songs_of(album, have, today):
            artist = track["artist"]["name"]
            if (key(artist), key(track["title"])) in seen:
                continue
            seen.add((key(artist), key(track["title"])))
            rows.append(
                [artist, track["title"], album["title"], track.get("duration", "")]
            )
            per_artist[name] += 1
            if per_artist[name] >= PER_ARTIST:
                break
        if len(rows) >= LIMIT:
            break

    # Written beside it and renamed over it, like everything sockseek reads.
    for path, write in (
        (
            cache_path,
            lambda f: json.dump(cache, f, ensure_ascii=False, indent=1, sort_keys=True),
        ),
        (
            out,
            lambda f: csv.writer(f).writerows(
                [["Artist", "Title", "Album", "Length"], *rows[:LIMIT]]
            ),
        ),
    ):
        fd, tmp = tempfile.mkstemp(
            dir=os.path.dirname(os.path.abspath(path)), prefix=".radar."
        )
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as f:
            write(f)
        os.replace(tmp, path)
    print(f"Release Radar: {min(len(rows), LIMIT)} songs from {len(found)} releases")


if __name__ == "__main__":
    main()
