"""Fill the gaps sockseek leaves in the Spotify playlists from the library.

sockseek writes "#FAIL: Artist - Title (123s) [Reason]" for every song it did
not download for that playlist, even when the library already has it: a
song that failed once is skipped as "not found last time" before sockseek
looks at the library at all, and its library match wants the exact title
("ex;curse velvet - 2026 Ver" is not "ex;curse velvet (2026 Ver)"). On
2026-11-16 two liked songs listed as failed had been downloaded for
another playlist.

Each such line is replaced by the path of a song in beets' library with the
same title, ignoring case and punctuation, one artist of exactly that name,
and a length within LENGTH_SLACK seconds, so a live or extended version is
not taken for the song. The artist is compared name by name: as a part of
the whole credit, "Ski Aggu" would also have found "Ski Aggu Musik", and
"Kid" every song by "Kid Cudi". Lines without a match stay as they are.

Usage: spotify-sync-resolve LIBRARY_DB PLAYLIST...
"""

from __future__ import annotations

import os
import re
import sqlite3
import sys
import unicodedata

FAIL = re.compile(r"^#FAIL: (?P<song>.*) \((?P<length>\d+)s\) \[\w+\]$")
LENGTH_SLACK = 10
# Between the names of one credit ("A, B & C feat. D", "A x B"), and beets'
# own separator in its multi-valued fields.
SEPARATORS = re.compile(
    r"\s*(?:[,;/&+]|\bfeat\.?|\bft\.|\bfeaturing\b|\bx\b|\\\u2400)\s*", re.IGNORECASE
)


def norm(text: str) -> str:
    """Letters and digits only, case- and accent-folded."""
    text = unicodedata.normalize("NFKD", text.casefold())
    return "".join(c for c in text if c.isalnum())


Library = dict[str, list[tuple[frozenset[str], str, float]]]


def names(credits: list[str | None]) -> frozenset[str]:
    """Every artist named in the credits, and each credit as a whole: a band
    may have a comma or an ampersand in its name."""
    found = set()
    for credit in filter(None, credits):
        found.add(norm(credit))
        found.update(norm(name) for name in SEPARATORS.split(credit))
    found.discard("")
    return frozenset(found)


def load(db: str) -> Library:
    """Songs by normalised title: (normalised artist names, path, length)."""
    songs: Library = {}
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=60)
    try:
        rows = con.execute(
            "SELECT title, artist, albumartist, artists, path, length FROM items"
        )
        for title, *credits, path, length in rows:
            if not title or not path:
                continue
            path = os.fsdecode(path)
            artists = names(credits)
            songs.setdefault(norm(title), []).append((artists, path, length or 0.0))
    finally:
        con.close()
    return songs


def find(songs: Library, song: str, length: int) -> str | None:
    """Closest-length library file for "Artist - Title".

    sockseek writes only the first artist, and either part may itself
    contain " - ", so every split is tried.
    """
    parts = song.split(" - ")
    best: tuple[float, str] | None = None
    for i in range(1, len(parts)):
        artist = norm(" - ".join(parts[:i]))
        title = norm(" - ".join(parts[i:]))
        if not artist or not title:
            continue
        for artists, path, seconds in songs.get(title, []):
            diff = abs(seconds - length)
            if artist in artists and diff <= LENGTH_SLACK and os.path.exists(path):
                if best is None or diff < best[0]:
                    best = (diff, path)
    return best[1] if best else None


def resolve(songs: Library, playlist: str) -> None:
    with open(playlist, encoding="utf-8") as f:
        lines = f.read().splitlines()

    # A song sockseek did download may still have a #FAIL line from an
    # earlier run; it is listed once.
    listed = {line for line in lines if line and not line.startswith("#")}
    found = 0
    out = []
    for line in lines:
        m = FAIL.match(line)
        path = m and find(songs, m["song"], int(m["length"]))
        if path and path not in listed:
            listed.add(path)
            found += 1
            out.append(path)
        else:
            out.append(line)
    if not found:
        return

    # Written beside it and renamed over it, so Navidrome never reads half a
    # playlist. The hidden name is no playlist to Navidrome.
    folder, name = os.path.split(playlist)
    part = os.path.join(folder, f".{name}.resolve")
    with open(part, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    os.replace(part, playlist)
    print(f"{name}: {found} songs found in the library")


def main() -> None:
    db, *playlists = sys.argv[1:]
    songs = load(db)
    for playlist in playlists:
        resolve(songs, playlist)


if __name__ == "__main__":
    main()
