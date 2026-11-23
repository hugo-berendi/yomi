"""Keep beets from tagging a song as a different version of itself.

beets weighs a parenthesised title suffix at a fraction of the rest of the
title, so "Summertime Sadness" matched "Summertime Sadness (radio mix)" at
98% and "Spring" matched "Spring (DJ TÖRKE remix)" on 2026-11-16. Nothing in
beets 2.14 lets a plugin add to a candidate's distance any more, so this
plugin steps in after beets has chosen: a song whose chosen match names a
different version (remix, edit, sped up, live, ...) takes the closest
candidate that agrees, if one is close enough, and otherwise keeps its own
tags.

Only songs imported on their own (singletons) are checked. An album match
is decided by its whole track list, which a single track's suffix does not
overturn.
"""

from __future__ import annotations

import os
import re
from typing import TYPE_CHECKING

from beets import config
from beets.autotag.match import TrackMatch
from beets.importer import Action, SingletonImportTask
from beets.plugins import BeetsPlugin

if TYPE_CHECKING:
    from beets.importer import ImportSession, ImportTask

# Suffixes that say nothing about which recording it is. Removed before the
# version words below are looked for, so "Original Mix" is not a mix.
NEUTRAL = re.compile(
    r"original (mix|version)|(album|single|radio) version"
    r"|(\d{4} )?remaster(ed)?( \d{4})?( version)?|explicit|clean|mono|stereo"
    r"|feat\.?|featuring|\bft\.?",
)

# Each kind of version, by the words that name it.
VERSIONS = {
    "mix": re.compile(r"\w*mix\b|rework|bootleg|\bvip\b"),
    "edit": re.compile(r"\bedit\b"),
    "sped up": re.compile(r"\bsped\b|speed(ed)? up|nightcore"),
    "slowed": re.compile(r"slowed|reverb"),
    "live": re.compile(r"\blive\b"),
    "acoustic": re.compile(r"acoustic|unplugged"),
    "instrumental": re.compile(r"instrumental|karaoke|backing track"),
    "a cappella": re.compile(r"a ?capp?ella"),
    "cover": re.compile(r"\bcover\b"),
    "demo": re.compile(r"\bdemo\b"),
    "extended": re.compile(r"\bextended\b"),
}

BRACKETS = re.compile(r"[(\[]([^)\]]*)[)\]]")


def _versions_in(suffixes: list[str]) -> frozenset[str]:
    text = NEUTRAL.sub(" ", " | ".join(suffixes).lower())
    return frozenset(k for k, pat in VERSIONS.items() if pat.search(text))


def title_versions(title: str | None) -> frozenset[str]:
    """Versions a title names in brackets or after its last " - "."""
    if not title:
        return frozenset()
    suffixes = BRACKETS.findall(title)
    parts = BRACKETS.sub("", title).split(" - ")
    if len(parts) > 1:
        suffixes.append(parts[-1])
    return _versions_in(suffixes)


def file_versions(path: bytes | str) -> frozenset[str]:
    """Versions a file name such as "01. Artist - Title - Sped Up" names.

    The first " - " separates artist and title, so only a further one starts
    a suffix.
    """
    stem = os.path.splitext(os.path.basename(os.fsdecode(path)))[0]
    suffixes = BRACKETS.findall(stem)
    parts = BRACKETS.sub("", stem).split(" - ")
    if len(parts) > 2:
        suffixes.append(parts[-1])
    return _versions_in(suffixes)


class VersionGuardPlugin(BeetsPlugin):
    def __init__(self) -> None:
        super().__init__()
        self.register_listener("import_task_choice", self.check_choice)

    # beets passes listener arguments by name, so `session` keeps its name.
    def check_choice(self, session: ImportSession, task: ImportTask) -> None:  # noqa: ARG002
        if not isinstance(task, SingletonImportTask):
            return
        match = task.match
        if task.choice_flag is not Action.APPLY or not isinstance(match, TrackMatch):
            return

        item = task.item
        wanted = title_versions(item.title) | file_versions(item.path)
        if title_versions(match.info.title) == wanted:
            return

        limit = config["match"]["strong_rec_thresh"].as_number()
        for candidate in task.candidates or []:
            if (
                isinstance(candidate, TrackMatch)
                and candidate.distance.distance <= limit
                and title_versions(candidate.info.title) == wanted
            ):
                self._log.warning(
                    "{}: took {!r} over {!r}, another version",
                    os.fsdecode(item.path),
                    candidate.info.title,
                    match.info.title,
                )
                task.set_choice(candidate)
                return

        self._log.warning(
            "{}: kept as is; {!r} is another version",
            os.fsdecode(item.path),
            match.info.title,
        )
        task.set_choice(Action.ASIS)
