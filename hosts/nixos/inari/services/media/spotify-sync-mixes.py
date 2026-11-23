"""Write Navidrome playlists: mixes per artist and genre, and a few lists.

Navidrome imports every .nsp file in the playlists folder as a smart
playlist and evaluates its rules itself, against its own play counts and
dates. For most playlists this only decides which rules to write:

- A mix for each artist with at least ARTIST_MIN_SONGS songs, together with
  the RELATED artists closest to them; none for an artist without any, and
  none that would be nearly the same as a mix already made for a bigger
  artist (01099, Gustav, Paul and Zachi are one crew, and one mix).
  Closeness comes from the library itself: artists credited on the same
  song, artists in the same Spotify playlists (a small playlist says more
  than the liked songs), and shared genres.

  An artist mix is a plain .m3u, chosen here: at least every second song is
  the artist's own, which no rule can say, and it changes once a week. Each
  artist's songs are shuffled once, by a hash of artist and path, and every
  week the mix takes the next ones in that order, so a mix only repeats a
  song once it has gone through all of them, and is shuffled anew. A mix of
  the smart-playlist kind was random on every refresh and could be mostly
  the other artists.
- A mix for each family of genres with at least GENRE_MIN_SONGS songs.
  beets' genres come in variants ("Hip Hop", "Hip-Hop"); a family lists every
  variant the library has, since Navidrome compares names exactly. The
  artists in MIXES_LEAVE_OUT (separated by ";") are left out of them: an
  80-song lullaby album tagged House would be half of "Electronic".
- The fixed lists in FIXED.

Names are compared as Navidrome stores them: an artist from the ARTISTS tag
when beets wrote one, otherwise split from ARTIST as Navidrome splits it, and
genres split at ";", "/" and ",". Navidrome leaves a credit such as "Mr.
Polska, Ski Aggu, Natte Visstick" whole, so a mix names it as it is, and the
artists in it count each on their own.

Each playlist's cover is drawn by spotify-sync-art.py, from what is written
to COVERS_JSON: the style, and the album folders of its biggest artist or
genre.

A file is only rewritten when its content changes, so Navidrome does not
reimport it on every run. Files are never removed: Navidrome keeps the
playlist of a deleted file, so a mix that drops out stays as it was. The
one exception is the .nsp an artist mix had before it became an .m3u; its
playlist stays in Navidrome until it is deleted there.

beets 2.14 stores a path relative to its music directory, MUSIC_DIR here;
the playlists name it in full.

Usage: MUSIC_DIR=... spotify-sync-mixes LIBRARY_DB PLAYLIST_DIR COVERS_JSON
"""

from __future__ import annotations

import collections
import datetime
import hashlib
import json
import math
import os
import random
import re
import sqlite3
import sys
import tempfile

ARTIST_MIN_SONGS = 6
MAX_ARTIST_MIXES = 25
RELATED = 5
GENRE_MIN_SONGS = 20
# Two artist mixes sharing this much of their artists are one too many.
MAX_OVERLAP = 0.5
MIX_LENGTH = 50
LIKED = "Lieblingssongs.m3u"
# First line of an artist mix. Spotify playlists say which artists belong
# together; a mix must not, or each one would confirm the next.
MARK = "#EXTM3U\n# spotify-sync-mixes\n"

# Navidrome's mappings.yaml: how a single ARTIST tag is split.
ARTIST_SPLIT = re.compile(r" / | feat\. | feat | ft\. | ft |; ")
# What Navidrome leaves in one name: "A, B & C", "A x B".
CREDIT_SPLIT = re.compile(r", | & | x ")
GENRE_SPLIT = re.compile(r"[;/,]")
# beets' separator in its multi-valued fields.
BEETS_LIST = "\\␀"

# Mix name, then words a genre's name is made of (letters only, lower case).
# A genre belongs to the first family one of whose words it contains.
FAMILIES = [
    ("Hip-Hop", ["hiphop", "rap", "trap", "gfunk", "phonk", "drill", "grime"]),
    (
        "Electronic",
        [
            "electronic",
            "house",
            "techno",
            "electro",
            "dance",
            "edm",
            "trance",
            "dubstep",
            "drumandbass",
            "dnb",
        ],
    ),
    ("Rock", ["rock", "punk", "metal", "grunge"]),
    ("Indie", ["indie", "alternative", "singersongwriter", "folk"]),
    ("Pop", ["pop"]),
    ("R&B und Soul", ["rnb", "randb", "soul", "funk"]),
]

FIXED = {
    "Lange nicht gehört": {
        "comment": "Lieblingssongs, die seit zwei Monaten nicht liefen",
        "all": [
            {"inPlaylist": {"path": None}},  # LIKED, filled in by main()
            {"notInTheLast": {"lastplayed": 60}},
        ],
        "sort": "random",
        "limit": MIX_LENGTH,
    },
    "Neu in der Bibliothek": {
        "comment": "Was in den letzten 30 Tagen dazukam",
        "all": [{"inTheLast": {"dateadded": 30}}],
        "sort": "dateadded",
        "order": "desc",
        "limit": 100,
    },
    "Noch nie gehört": {
        "comment": "Heruntergeladen, aber noch nie abgespielt",
        "all": [{"lt": {"playcount": 1}}],
        "sort": "random",
        "limit": MIX_LENGTH,
    },
    "Dauerschleife": {
        "comment": "Oft gehört und im letzten Monat wieder",
        "all": [
            {"inTheLast": {"lastplayed": 30}},
            {"gt": {"playcount": 4}},
        ],
        "sort": "playcount",
        "order": "desc",
        "limit": MIX_LENGTH,
    },
}


def key(text: str) -> str:
    return "".join(c for c in text.casefold() if c.isalnum())


def split_names(text: str | None, pattern: re.Pattern) -> list[str]:
    return [n.strip() for n in pattern.split(text or "") if n.strip()]


class Library:
    def __init__(self, db: str) -> None:
        self.artists: dict[str, list[str]] = {}  # path -> artists
        self.names: dict[str, set[str]] = collections.defaultdict(
            set
        )  # artist -> names in Navidrome
        self.songs: collections.Counter[str] = collections.Counter()
        self.genres: dict[str, collections.Counter[str]] = collections.defaultdict(
            collections.Counter
        )
        self.genre_songs: collections.Counter[str] = collections.Counter()
        self.credited = collections.Counter()  # (a, b) on one song
        # (artists, genres, path) per song
        self.items: list[tuple[list[str], list[str], str]] = []
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=60)
        try:
            rows = con.execute(
                "SELECT artist, artists, genres, path FROM items"
            ).fetchall()
        finally:
            con.close()
        for artist, artists, tags, path in rows:
            names = [n for n in (artists or "").split(BEETS_LIST) if n.strip()]
            names = list(dict.fromkeys(names or split_names(artist, ARTIST_SPLIT)))
            parts = []
            for name in names:
                for part in split_names(name, CREDIT_SPLIT) or [name]:
                    self.names[part].add(name)
                    parts.append(part)
            names = list(dict.fromkeys(parts))
            # A list in beets 2.14, written to the file as one GENRE value
            # per entry; lastgenre may still put several into one.
            genres = [
                g
                for tag in (tags or "").split(BEETS_LIST)
                for g in split_names(tag, GENRE_SPLIT)
            ]
            genres = list(dict.fromkeys(genres))
            full_path = os.path.join(os.environ["MUSIC_DIR"], os.fsdecode(path))
            self.artists[full_path] = names
            for name in names:
                self.songs[name] += 1
                self.genres[name].update(genres)
            for a in names:
                for b in names:
                    if a != b:
                        self.credited[a, b] += 1
            self.genre_songs.update(genres)
            self.items.append((names, genres, full_path))


def playlists_together(lib: Library, folder: str) -> collections.Counter:
    """How strongly the Spotify playlists put two artists together."""
    together = collections.Counter()
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".m3u") or name.startswith("."):
            continue
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            text = f.read()
        if text.startswith(MARK):
            continue
        paths = [
            line.strip()
            for line in text.splitlines()
            if line.strip() and not line.startswith("#")
        ]
        present = {a for p in paths for a in lib.artists.get(p, [])}
        if len(present) < 2:
            continue
        weight = 1 / math.log2(1 + len(present))
        for a in present:
            for b in present:
                if a != b:
                    together[a, b] += weight
    return together


def cosine(a: collections.Counter, b: collections.Counter) -> float:
    dot = sum(n * b[g] for g, n in a.items())
    norm = math.sqrt(sum(n * n for n in a.values())) * math.sqrt(
        sum(n * n for n in b.values())
    )
    return dot / norm if norm else 0.0


def folders(paths: list[str]) -> list[str]:
    """The album folders with the most of these songs, to take a cover from."""
    count = collections.Counter(os.path.dirname(p) for p in paths)
    return [f for f, _ in count.most_common(5)]


def this_week(
    artist: str, paths: list[str], count: int, week: int, step: int
) -> list[str]:
    """COUNT of the artist's songs in their order, starting STEP further on
    each week."""
    if not paths:
        return []
    order = sorted(
        paths, key=lambda p: hashlib.sha1(f"{artist}\0{p}".encode()).digest()
    )
    start = week * step % len(order)
    return [order[(start + i) % len(order)] for i in range(min(count, len(order)))]


def interleave(own: list[str], others: list[str]) -> list[str]:
    """The other songs spread evenly between the artist's own, never two of
    them in a row: there are never more of them than of the own."""
    songs = []
    placed = 0
    for i, song in enumerate(own, 1):
        songs.append(song)
        if placed < len(others) and placed * len(own) < i * len(others):
            songs.append(others[placed])
            placed += 1
    return songs


def mix_songs(lib: Library, artist: str, related: list[str], week: int) -> list[str]:
    own = [p for a, _, p in lib.items if artist in a]
    theirs = {
        o: [p for a, _, p in lib.items if o in a and artist not in a] for o in related
    }
    # Round the related artists, a song each, until there are enough. Each
    # starts this week where last week's mix stopped taking from them.
    step = -(-(MIX_LENGTH // 2) // max(len(related), 1))
    turns = {o: this_week(o, ps, len(ps), week, step) for o, ps in theirs.items()}
    pool = []
    for i in range(max(map(len, turns.values()), default=0)):
        pool += [ps[i] for ps in turns.values() if i < len(ps)]
    pool = list(dict.fromkeys(pool))
    n_others = min(len(pool), MIX_LENGTH // 2)
    n_own = min(len(own), MIX_LENGTH - n_others)
    own = this_week(artist, own, n_own, week, n_own)
    others = pool[: min(n_others, n_own)]
    # An artist with few songs has all of them in every week's mix; the
    # order still changes.
    shuffle = random.Random(f"{artist}\0{week}").shuffle
    shuffle(own)
    shuffle(others)
    return interleave(own, others)


def artist_mixes(
    lib: Library, together: collections.Counter, covers: dict[str, dict], week: int
) -> dict[str, list[str]]:
    mixes = {}
    made: list[set[str]] = []
    leaders = [
        a for a, n in lib.songs.most_common(MAX_ARTIST_MIXES) if n >= ARTIST_MIN_SONGS
    ]
    for artist in leaders:
        scores = {}
        for other, n in lib.songs.items():
            if other == artist or n < 2:
                continue
            credits = 0.5 * min(lib.credited[artist, other], 4)
            genres = cosine(lib.genres[artist], lib.genres[other])
            score = sum((together[artist, other], credits, genres))
            if score > 0.5:
                scores[other] = score
        related = sorted(scores, key=lambda o: (-scores[o], o))[:RELATED]
        cast = {artist, *related}
        if not related or any(
            len(cast & m) / len(cast | m) >= MAX_OVERLAP for m in made
        ):
            continue
        made.append(cast)
        covers[f"{artist} Mix"] = {
            "style": "artist",
            "artist": artist,
            "folders": folders([p for a, _, p in lib.items if artist in a]),
        }
        mixes[f"{artist} Mix"] = mix_songs(lib, artist, related, week)
    return mixes


def genre_mixes(
    lib: Library, leave_out: list[str], covers: dict[str, dict]
) -> dict[str, dict]:
    members: dict[str, list[str]] = collections.defaultdict(list)
    for genre in lib.genre_songs:
        k = key(genre)
        for family, words in FAMILIES:
            if any(w in k for w in words):
                members[family].append(genre)
                break
    mixes = {}
    # Indie and Pop share many albums; each mix shows one of its own.
    shown: set[str] = set()
    for family, _ in FAMILIES:
        genres = sorted(members[family])
        songs = [(a, p) for a, tags, p in lib.items if set(tags) & set(genres)]
        if len(songs) < GENRE_MIN_SONGS:
            continue
        left_out = sorted(
            a for a in leave_out if any(a in artists for artists, _ in songs)
        )
        comment = "Genres: " + ", ".join(genres)
        rules: list[dict] = [{"any": [{"is": {"genre": g}} for g in genres]}]
        if left_out:
            comment += ". Ohne " + ", ".join(left_out)
            names = sorted(set().union(*(lib.names[a] for a in left_out)))
            rules += [{"isNot": {"artist": name}} for name in names]
        covers[f"{family} Mix"] = {
            "style": "genre",
            "title": family,
            "folders": [
                f
                for f in folders([p for a, p in songs if not set(a) & set(left_out)])
                if f not in shown
            ],
        }
        shown.update(covers[f"{family} Mix"]["folders"][:1])
        mixes[f"{family} Mix"] = {
            "comment": comment,
            "all": rules,
            "sort": "random",
            "limit": MIX_LENGTH * 2,
        }
    return mixes


def write_covers(path: str, covers: dict[str, dict]) -> None:
    fd, tmp = tempfile.mkstemp(
        dir=os.path.dirname(os.path.abspath(path)), prefix=".covers."
    )
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(covers, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def write(folder: str, name: str, content: str, suffix: str) -> bool:
    """Writes NAME.SUFFIX unless it already says the same; True if it changed."""
    filename = re.sub(r'[/\\:*?"<>|]', "_", name) + suffix
    path = os.path.join(folder, filename)
    try:
        with open(path, encoding="utf-8") as f:
            if f.read() == content:
                return False
    except FileNotFoundError:
        pass
    # Hidden while written: Navidrome never reads half a playlist.
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=f".{filename}.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(content)
    os.chmod(tmp, 0o664)
    os.replace(tmp, path)
    return True


def main() -> None:
    db, folder, covers_path = sys.argv[1:]
    lib = Library(db)
    covers = {name: {"style": "list"} for name in FIXED}
    smart = {
        **FIXED,
        **genre_mixes(
            lib,
            split_names(os.environ.get("MIXES_LEAVE_OUT"), re.compile(";")),
            covers,
        ),
    }
    smart["Lange nicht gehört"]["all"][0]["inPlaylist"]["path"] = os.path.join(
        os.path.abspath(folder), LIKED
    )
    # Mondays, like ordinal 1, 0001-01-01.
    week = (datetime.date.today().toordinal() - 1) // 7
    mixes = artist_mixes(lib, playlists_together(lib, folder), covers, week)
    changed = [
        name
        for name, rules in smart.items()
        if write(
            folder,
            name,
            json.dumps({"name": name, **rules}, ensure_ascii=False, indent=2) + "\n",
            ".nsp",
        )
    ]
    for name, songs in mixes.items():
        if write(folder, name, MARK + "".join(f"{p}\n" for p in songs), ".m3u"):
            changed.append(name)
        old = os.path.join(folder, re.sub(r'[/\\:*?"<>|]', "_", name) + ".nsp")
        if os.path.exists(old):
            os.remove(old)
    write_covers(covers_path, covers)
    if changed:
        print(f"{len(changed)} smart playlists written: {', '.join(changed)}")


if __name__ == "__main__":
    main()
