"""List the new releases of the library's artists, for a Release Radar.

Takes the TOP_ARTISTS artists with the most songs in beets' library, looks
each up on Deezer's public API, and lists what they released in the last
WINDOW_DAYS days: every song of a single or EP, and the PER_ALBUM most
played songs of an album, newest release first, at most LIMIT songs. The
list is a CSV sockseek downloads like a playlist.

Deezer, not Spotify: Spotify's API gives development apps no new releases
since February 2026, and every request counts against the limit sockseek
needs. beets already asks Deezer for metadata.

An artist's name alone is not enough: there are many "Paul"s. Of the
Deezer artists with exactly that name, the one taken has an album or song
title in common with the library; without one the artist is skipped. The
choice is kept in CACHE, so this happens once per artist.

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

TOP_ARTISTS = 40
MIN_SONGS = 3
WINDOW_DAYS = 14
PER_ALBUM = 3
LIMIT = 50
API = "https://api.deezer.com"

# As in spotify-sync-mixes.py: how Navidrome and beets name artists.
ARTIST_SPLIT = re.compile(r" / | feat\. | feat | ft\. | ft |; ")
CREDIT_SPLIT = re.compile(r", | & | x ")
BEETS_LIST = "\\␀"


def key(text: str) -> str:
    return "".join(c for c in text.casefold() if c.isalnum())


def split_names(text: str | None, pattern: re.Pattern) -> list[str]:
    return [n.strip() for n in pattern.split(text or "") if n.strip()]


def library(db: str) -> tuple[collections.Counter, dict[str, set[str]]]:
    """Songs per artist, and the keys of each artist's album and song titles."""
    songs: collections.Counter[str] = collections.Counter()
    titles: dict[str, set[str]] = collections.defaultdict(set)
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
    return songs, titles


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
    for candidate in found:
        if key(candidate["name"]) != key(name):
            continue
        albums = get(f"artist/{candidate['id']}/albums", limit=100).get("data", [])
        tops = get(f"artist/{candidate['id']}/top", limit=50).get("data", [])
        theirs = {key(a["title"]) for a in albums} | {key(t["title"]) for t in tops}
        if theirs & known:
            return candidate["id"]
    return None


def releases(artist_id: int, since: datetime.date, today: datetime.date) -> list[dict]:
    albums = get(f"artist/{artist_id}/albums", limit=50).get("data", [])
    fresh = []
    for album in albums:
        try:
            released = datetime.date.fromisoformat(album.get("release_date", ""))
        except ValueError:
            continue
        if since <= released <= today:
            fresh.append({**album, "released": released})
    return fresh


def songs_of(album: dict) -> list[dict]:
    tracks = get(f"album/{album['id']}/tracks", limit=100).get("data", [])
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

    counts, titles = library(db)
    today = datetime.date.today()
    since = today - datetime.timedelta(days=WINDOW_DAYS)
    found: dict[int, dict] = {}
    for name, n in counts.most_common(TOP_ARTISTS):
        if n < MIN_SONGS:
            break
        if name not in cache:
            cache[name] = find_artist(name, titles[name])
            if cache[name] is None:
                print(f"{name}: not found on Deezer", file=sys.stderr)
        if cache[name] is not None:
            for album in releases(cache[name], since, today):
                found.setdefault(album["id"], album)

    rows = []
    seen = set()
    for album in sorted(
        found.values(), key=lambda a: (a["released"], a["id"]), reverse=True
    ):
        for track in songs_of(album):
            artist = track["artist"]["name"]
            if (key(artist), key(track["title"])) in seen:
                continue
            seen.add((key(artist), key(track["title"])))
            rows.append(
                [artist, track["title"], album["title"], track.get("duration", "")]
            )

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
