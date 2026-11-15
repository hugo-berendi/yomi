#!/usr/bin/env bash
# Retags what spotify-sync downloaded, with the best metadata beets finds.
#
# sockseek's on-complete hook queues every finished download as
#   kind <TAB> spotify-uri <TAB> path [<TAB> attempts]
# where kind is "track" (a song, with its Spotify URI), or "album" (a whole
# album folder). Songs are tagged from exactly the Spotify track they were
# downloaded for; albums are matched against MusicBrainz, Spotify and Deezer,
# closest candidate wins. Without a close enough match a file keeps its own
# tags. Files are written in place: sockseek's indexes and the .m3u playlists
# point at their paths.
#
# Set by spotify-sync.nix: MUSIC_DIR, STATE_DIR, BEETS_CONFIG, BEETSDIR.
set -euo pipefail

queue=$STATE_DIR/beets-queue
work=$STATE_DIR/beets-queue.work
lock=$STATE_DIR/beets-queue.lock
playlist_dir=$MUSIC_DIR/playlists
mkdir -p "$BEETSDIR"

# MusicBrainz answers 503 when busy; such an entry is retried on the next
# runs instead of being dropped as "kept as is".
max_attempts=3

beet() { command beet -c "$BEETS_CONFIG" "$@"; }

# beets' Spotify plugin sleeps out whatever Retry-After a 429 names, and logs
# it only at debug level: on 2026-11-15 one song sat silent for hours, with
# the whole queue behind it. An import that needs longer is retried later.
import_timeout=10m

# {{{ Backfill
# Files downloaded before tagging existed: folders of four or more songs are
# albums, anything else is looked up song by song.
if [[ ! -e $STATE_DIR/beets-backfilled ]]; then
	while IFS= read -r -d '' dir; do
		mapfile -d '' -t songs < <(find "$dir" -maxdepth 1 -type f \
			\( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.opus' -o -iname '*.ogg' \) -print0)
		if [[ ${#songs[@]} -ge 4 ]]; then
			printf 'album\t-\t%s\n' "$dir"
		elif [[ ${#songs[@]} -gt 0 ]]; then
			printf 'single\t-\t%s\n' "${songs[@]}"
		fi
	done < <(find "$MUSIC_DIR" -mindepth 1 -type d \
		-not -path "$playlist_dir" -not -path '*/.sockseek-staging*' -print0) |
		flock "$lock" tee -a "$queue" >/dev/null
	touch "$STATE_DIR/beets-backfilled"
fi
# }}}

# tag ATTEMPTS IMPORT-ARGS... PATH
# Returns 1 when a source failed, so the caller can queue the entry again.
tag() {
	local attempts=$1 path=${*: -1} out status=0 retry=0
	shift
	out=$(timeout --kill-after=1m "$import_timeout" \
		beet -c "$BEETS_CONFIG" import -q "$@" 2>&1) || status=$?
	printf '%s\n' "$out"
	if ((status == 124 || status == 137)); then
		echo "beets took longer than $import_timeout on $path" >&2
		retry=1
	elif grep -q 'Error searching\|Max retries exceeded' <<<"$out"; then
		retry=1
	fi
	# Lyrics and genres found for a file kept as-is stay in beets' database
	# unless written out explicitly. Its output would list every changed
	# field, whole lyrics included.
	beet write "path:$path" >/dev/null || echo "could not write tags of $path" >&2
	if ((retry && attempts < max_attempts)); then
		return 1
	fi
}

# Spotify knows the song, not the release an uploader ripped it from: a hit
# taken from a compilation still carries that compilation's MusicBrainz IDs,
# and Navidrome groups albums by those IDs before anything else.
# shellcheck disable=SC2016 # $data_source and $albumartist are beets templates
drop_stale_ids() {
	[[ $(beet ls -f '$data_source' "path:$1") == Spotify ]] || return 0
	local fields=(mb_albumid= mb_releasegroupid= mb_releasetrackid= mb_trackid= mb_albumartistid= comp=false)
	# "Various Artists" from a compilation rip; Navidrome falls back to the
	# track artist.
	[[ $(beet ls -f '$albumartist' "path:$1") != *[Vv]arious* ]] || fields+=(albumartist=)
	beet modify -y "path:$1" "${fields[@]}" >/dev/null
}

# Take over the queue; hooks still running meanwhile start a new one.
{
	flock 9
	if [[ -s $queue ]]; then
		cat "$queue" >>"$work" && rm -f "$queue"
	fi
} 9>"$lock"
[[ -s $work ]] || exit 0

# fd 3: beets must not read the work list from stdin.
# shellcheck disable=SC2094 # sed -i writes a new file; fd 3 keeps the old one
while IFS=$'\t' read -r -u 3 kind uri path attempts; do
	attempts=$((${attempts:-0} + 1))
	# Files inside an album download have no URI of their own; the album
	# entry tags them together.
	if [[ -e $path && ($kind != track || $uri == spotify:track:*) ]]; then
		case $kind in
		album) tag "$attempts" "$path" ;;
		single) tag "$attempts" -s "$path" ;;
		track) tag "$attempts" -s --search-id "${uri##*:}" "$path" && drop_stale_ids "$path" ;;
		esac || printf '%s\t%s\t%s\t%s\n' "$kind" "$uri" "$path" "$attempts" |
			flock "$lock" tee -a "$queue" >/dev/null
	fi
	# Done with this entry: a stopped run resumes after it, not from the top.
	# fd 3 still reads the old file, which sed replaces rather than edits.
	sed -i 1d "$work"
done 3<"$work"
rm -f "$work"
