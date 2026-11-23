"""List the folders of the music library that have no cover.

A folder has one when it holds an image file Navidrome takes as the album's
cover, or when a song in it has a picture embedded. beets only fetches a
cover for what it matched: a song kept with its own tags, or one that failed
to tag, ends up in Navidrome and Symfonium without one. On 2026-11-17 that
was 27 of 275 folders, found by hand.

The list goes to OUTPUT, one folder per line, replaced as a whole; the count
goes to the journal.

Usage: spotify-sync-covers MUSIC_DIR OUTPUT
"""

from __future__ import annotations

import os
import sys
import tempfile

import mutagen

AUDIO = {".flac", ".mp3", ".m4a", ".opus", ".ogg"}
# Navidrome's default CoverArtPriority, without the embedded entry.
IMAGE_STEMS = {"cover", "folder", "front"}
IMAGES = {".jpg", ".jpeg", ".png", ".webp"}
SKIP = {"playlists"}


def has_picture(path: str) -> bool:
    try:
        audio = mutagen.File(path)
    except (mutagen.MutagenError, OSError):
        return False
    if audio is None:
        return False
    if getattr(audio, "pictures", None):  # FLAC
        return True
    tags = audio.tags
    if tags is None:
        return False
    # mutagen's tag containers do not all iterate over their keys (Vorbis
    # comments yield pairs), so ask for the keys.
    return any(is_picture(key) for key in tags.keys())  # noqa: SIM118


def is_picture(key: str) -> bool:
    # ID3, MP4, and Ogg Vorbis and Opus.
    return key.startswith("APIC") or key.lower() in ("covr", "metadata_block_picture")


def is_cover(name: str) -> bool:
    stem, ext = os.path.splitext(name.lower())
    return stem in IMAGE_STEMS and ext in IMAGES


def missing(music_dir: str) -> list[str]:
    found = []
    for root, dirs, files in os.walk(music_dir):
        dirs[:] = sorted(d for d in dirs if d not in SKIP and not d.startswith("."))
        songs = sorted(f for f in files if os.path.splitext(f)[1].lower() in AUDIO)
        if not songs:
            continue
        if any(is_cover(f) for f in files):
            continue
        if not any(has_picture(os.path.join(root, song)) for song in songs):
            found.append(root)
    return found


def main() -> None:
    music_dir, output = sys.argv[1], sys.argv[2]
    folders = missing(music_dir)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(output), prefix=".missing-covers.")
    with os.fdopen(fd, "w") as file:
        file.writelines(f"{folder}\n" for folder in folders)
    os.replace(tmp, output)
    if folders:
        print(
            f"{len(folders)} folders have no cover; listed in {output}", file=sys.stderr
        )


if __name__ == "__main__":
    main()
