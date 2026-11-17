"""Draw covers for the generated playlists, in the manner of Spotify's mixes.

Navidrome takes an image beside a playlist file, with the same name, as
that playlist's cover; without one it tiles four random album covers, and a
mix then looks like any other playlist. Each cover here is a photo toned in
the playlist's own two colours, with its name written large:

- artist: the artist's photo from Deezer, else an album cover of theirs.
  Only Deezer artists spotify-sync-radar.py has matched against the library
  (DEEZER_ARTISTS), so a "Paul" gets no stranger's face.
- genre: an album cover of the genre, tilted, on its colours.
- list: the colours alone.
- Release Radar: the cover of its newest release, which leads the playlist.
- top: Kodama's top songs of a year or month, the cover of the top song's
  album, tilted, under the year or month.

SPEC_JSON comes from spotify-sync-mixes.py: per playlist name, the style,
and the folders to take an album cover from. Kodama writes the same for its
playlists, as KODAMA_COVERS in PLAYLIST_DIR. Colours follow from the name,
so a cover only changes when its picture does; an image is only rewritten
when its bytes change, like the playlists.

Usage: spotify-sync-art SPEC_JSON PLAYLIST_DIR DEEZER_ARTISTS IMAGE_CACHE
"""

from __future__ import annotations

import base64
import io
import json
import os
import re
import sys
import tempfile
import urllib.request
import zlib

import mutagen
import mutagen.flac
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

SIZE = 1000
MARGIN = 72
FONTS = "@fonts@"
RADAR = "Release Radar"
KODAMA_COVERS = ".kodama-covers.json"
# (dark, light) per playlist, picked by its name.
PALETTE = [
    ("#0b1a4a", "#5b9bff"),
    ("#3a0838", "#ff5fae"),
    ("#032b27", "#38e0b0"),
    ("#3a1600", "#ffa040"),
    ("#24094f", "#b28cff"),
    ("#3a0b0b", "#ff6b5b"),
    ("#232800", "#d9f560"),
    ("#00263a", "#4fd8ff"),
]
AUDIO = {".flac", ".mp3", ".m4a", ".opus", ".ogg"}
COVER_STEMS = {"cover", "folder", "front"}
IMAGES = {".jpg", ".jpeg", ".png", ".webp"}


def colours(name: str) -> tuple[str, str]:
    return PALETTE[zlib.crc32(name.encode()) % len(PALETTE)]


def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(os.path.join(FONTS, f"Figtree-{weight}.otf"), size)


# {{{ Pictures
def folder_cover(folder: str) -> Image.Image | None:
    """The folder's cover file, else the picture embedded in its first song."""
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return None
    for name in names:
        stem, ext = os.path.splitext(name.lower())
        if stem in COVER_STEMS and ext in IMAGES:
            return open_image(os.path.join(folder, name))
    for name in names:
        if os.path.splitext(name)[1].lower() in AUDIO:
            data = embedded(os.path.join(folder, name))
            if data:
                return open_image(io.BytesIO(data))
    return None


def embedded(path: str) -> bytes | None:
    try:
        audio = mutagen.File(path)
    except (mutagen.MutagenError, OSError):
        return None
    if audio is None:
        return None
    if getattr(audio, "pictures", None):  # FLAC
        return audio.pictures[0].data
    tags = audio.tags or {}
    for key in tags.keys():
        if key.startswith("APIC"):  # ID3
            return tags[key].data
        if key == "covr":  # MP4
            return bytes(tags[key][0])
        if key.lower() == "metadata_block_picture":  # Ogg Vorbis and Opus
            raw = base64.b64decode(tags[key][0])
            return mutagen.flac.Picture(raw).data
    return None


def open_image(source) -> Image.Image | None:
    try:
        image = Image.open(source)
        image.load()
        return image.convert("RGB")
    except (OSError, ValueError, Image.DecompressionBombError):
        return None


def get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "spotify-sync-art"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read()


def artist_photo(name: str, deezer: dict, cache: str) -> Image.Image | None:
    """The Deezer photo of a matched artist, downloaded once."""
    artist_id = deezer.get(name)
    if artist_id is None:
        return None
    path = os.path.join(cache, f"deezer-{artist_id}.jpg")
    none = path + ".none"
    if not os.path.exists(path) and not os.path.exists(none):
        try:
            url = json.loads(get(f"https://api.deezer.com/artist/{artist_id}")).get(
                "picture_xl"
            )
            # Deezer's placeholder for an artist without a photo.
            if not url or "/artist//" in url:
                open(none, "w").close()
                return None
            data = get(url)
        except (OSError, ValueError) as error:
            print(f"{name}: no Deezer photo ({error})", file=sys.stderr)
            return None
        fd, tmp = tempfile.mkstemp(dir=cache, prefix=".deezer.")
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.replace(tmp, path)
    return open_image(path) if os.path.exists(path) else None


def first_cover(folders: list[str]) -> Image.Image | None:
    for folder in folders:
        image = folder_cover(folder)
        if image is not None:
            return image
    return None


# }}}
# {{{ Drawing
def square(image: Image.Image, size: int) -> Image.Image:
    return ImageOps.fit(image, (size, size), Image.Resampling.LANCZOS)


def duotone(image: Image.Image, dark: str, light: str) -> Image.Image:
    grey = ImageOps.autocontrast(ImageOps.grayscale(image), cutoff=1)
    return ImageOps.colorize(grey, black=dark, white=light, mid=None)


def gradient(dark: str, light: str, corner: str) -> Image.Image:
    """Diagonal, from the dark colour into the light one in CORNER."""
    # Both run from 0 to 255: down from the top, across from the left.
    down = Image.linear_gradient("L").resize((SIZE, SIZE))
    across = down.transpose(Image.Transpose.ROTATE_90)
    if corner == "top-right":
        down = ImageOps.flip(down)
    mask = Image.blend(down, across, 0.5)
    return Image.composite(
        Image.new("RGB", (SIZE, SIZE), light),
        Image.new("RGB", (SIZE, SIZE), dark),
        mask,
    )


def shade(image: Image.Image, start: float) -> Image.Image:
    """Darkens the lower part, where the title goes."""
    mask = Image.linear_gradient("L").resize((SIZE, SIZE))
    mask = mask.point(lambda v: max(0, int((v / 255 - start) / (1 - start) * 200)))
    return Image.composite(Image.new("RGB", (SIZE, SIZE), "black"), image, mask)


def wrap(text: str, size: int, lines: int) -> tuple[ImageFont.FreeTypeFont, list[str]]:
    """The biggest font, down from SIZE, that fits TEXT in LINES lines."""
    width = SIZE - 2 * MARGIN
    for points in range(size, 40, -4):
        face = font("ExtraBold", points)
        wrapped: list[str] = []
        for word in text.split():
            line = f"{wrapped[-1]} {word}" if wrapped else word
            if wrapped and face.getlength(line) <= width:
                wrapped[-1] = line
            else:
                wrapped.append(word)
        if len(wrapped) <= lines and all(face.getlength(w) <= width for w in wrapped):
            return face, wrapped
    return font("ExtraBold", 40), [text]


def title(
    draw: ImageDraw.ImageDraw, text: str, label: str, accent: str, top: bool
) -> None:
    face, lines = wrap(text, 150, 3 if top else 2)
    step = int(face.size * 1.02)
    small = font("Bold", 40)
    if top:
        y = MARGIN
        for line in lines:
            draw.text((MARGIN, y), line, font=face, fill="white")
            y += step
    else:
        y = SIZE - MARGIN - 30 - step * len(lines)
        draw.text((MARGIN, y - 62), label.upper(), font=small, fill=accent)
        for line in lines:
            draw.text((MARGIN, y), line, font=face, fill="white")
            y += step


def bar(draw: ImageDraw.ImageDraw, accent: str) -> None:
    draw.rectangle((0, SIZE - 22, SIZE, SIZE), fill=accent)


def photo_cover(
    picture: Image.Image | None, text: str, label: str, name: str
) -> Image.Image:
    dark, light = colours(name)
    if picture is None:
        canvas = gradient(dark, light, "top-right")
    else:
        canvas = shade(duotone(square(picture, SIZE), dark, light), 0.45)
    draw = ImageDraw.Draw(canvas)
    title(draw, text, label, light, top=False)
    bar(draw, light)
    return canvas


def tilted_cover(
    picture: Image.Image | None, text: str, label: str, name: str
) -> Image.Image:
    dark, light = colours(name)
    canvas = gradient(dark, light, "top-right")
    if picture is not None:
        art = square(picture, 560).convert("RGBA")
        art = art.rotate(-9, resample=Image.Resampling.BICUBIC, expand=True)
        shadow = Image.new("RGBA", art.size, (0, 0, 0, 0))
        shadow.putalpha(art.getchannel("A").point(lambda a: a * 0.55))
        shadow = shadow.filter(ImageFilter.GaussianBlur(24))
        x, y = SIZE - art.width + 90, -60
        canvas.paste(shadow, (x + 18, y + 28), shadow)
        canvas.paste(art, (x, y), art)
        canvas = shade(canvas, 0.5)
    draw = ImageDraw.Draw(canvas)
    title(draw, text, label, light, top=False)
    bar(draw, light)
    return canvas


def list_cover(text: str, name: str) -> Image.Image:
    dark, light = colours(name)
    canvas = gradient(dark, light, "bottom-right")
    rings = Image.new("L", (SIZE, SIZE), 0)
    ring = ImageDraw.Draw(rings)
    for r in (520, 400, 280):
        ring.ellipse(
            (SIZE - r - 120, SIZE - r - 120, SIZE + r - 120, SIZE + r - 120),
            outline=90,
            width=26,
        )
    canvas = Image.composite(Image.new("RGB", (SIZE, SIZE), light), canvas, rings)
    draw = ImageDraw.Draw(canvas)
    title(draw, text, "", light, top=True)
    bar(draw, light)
    return canvas


# }}}
def render(name: str, spec: dict, deezer: dict, cache: str) -> Image.Image:
    style = spec["style"]
    folders = spec.get("folders", [])
    if style == "artist":
        artist = spec["artist"]
        picture = artist_photo(artist, deezer, cache) or first_cover(folders)
        return photo_cover(picture, artist, "Mix", name)
    if style == "genre":
        return tilted_cover(first_cover(folders), spec["title"], "Mix", name)
    if style == "radar":
        return photo_cover(first_cover(folders), name, "Neu von deinen Artists", name)
    if style == "top":
        return tilted_cover(first_cover(folders), spec["title"], spec["label"], name)
    return list_cover(name, name)


def radar_spec(folder: str) -> dict | None:
    """The newest release leads the Release Radar."""
    try:
        with open(os.path.join(folder, f"{RADAR}.m3u"), encoding="utf-8") as f:
            songs = [
                line.strip() for line in f if line.strip() and not line.startswith("#")
            ]
    except FileNotFoundError:
        return None
    return {"style": "radar", "folders": [os.path.dirname(s) for s in songs[:5]]}


def write(folder: str, name: str, image: Image.Image) -> bool:
    buffer = io.BytesIO()
    image.save(buffer, "JPEG", quality=88)
    data = buffer.getvalue()
    path = os.path.join(folder, re.sub(r'[/\\:*?"<>|]', "_", name) + ".jpg")
    try:
        with open(path, "rb") as f:
            if f.read() == data:
                return False
    except FileNotFoundError:
        pass
    # Hidden while written, like the playlists.
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".cover.")
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    os.chmod(tmp, 0o664)
    os.replace(tmp, path)
    return True


def main() -> None:
    spec_path, folder, deezer_path, cache = sys.argv[1:]
    with open(spec_path, encoding="utf-8") as f:
        specs: dict[str, dict] = json.load(f)
    try:
        with open(deezer_path, encoding="utf-8") as f:
            deezer = json.load(f)
    except FileNotFoundError:
        deezer = {}
    radar = radar_spec(folder)
    if radar:
        specs[RADAR] = radar
    try:
        with open(os.path.join(folder, KODAMA_COVERS), encoding="utf-8") as f:
            specs.update(json.load(f))
    except FileNotFoundError:
        pass
    os.makedirs(cache, exist_ok=True)
    changed = [
        name
        for name, spec in specs.items()
        if write(folder, name, render(name, spec, deezer, cache))
    ]
    if changed:
        print(f"{len(changed)} playlist covers drawn: {', '.join(changed)}")


if __name__ == "__main__":
    main()
