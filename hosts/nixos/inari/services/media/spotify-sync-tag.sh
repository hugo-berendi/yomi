#!/usr/bin/env bash
# Retags what spotify-sync downloaded, with the best metadata beets finds.
#
# sockseek's on-complete hook queues every finished download as
#   kind <TAB> spotify-uri <TAB> path [<TAB> attempts]
# where kind is "track" (a song, with its Spotify URI), or "album" (a whole
# album folder). Songs are tagged from exactly the Spotify track they were
# downloaded for; everything else is matched against MusicBrainz and Deezer,
# closest candidate wins. Without a close enough match a file keeps its own
# tags. Files are written in place: sockseek's indexes and the .m3u playlists
# point at their paths.
#
# Set by spotify-sync.nix: MUSIC_DIR, STATE_DIR, BEETS_CONFIG,
# BEETS_SPOTIFY_CONFIG (the same plus Spotify), BEETSDIR.
set -euo pipefail

queue=$STATE_DIR/beets-queue
# Entries beets failed on max_attempts times, in the queue's format without
# the attempts: appending them to the queue tries them again.
failed=$STATE_DIR/beets-failed
work=$STATE_DIR/beets-queue.work
lock=$STATE_DIR/beets-queue.lock
playlist_dir=$MUSIC_DIR/playlists
mkdir -p "$BEETSDIR"

# An entry beets failed on is retried on the next runs, and then listed in
# $failed: MusicBrainz answers 503 when busy, and a file dropped from the
# queue keeps its old tags, often without a cover, while the unit succeeds.
max_attempts=3

beet() { command beet -c "$BEETS_CONFIG" "$@"; }

# An import that needs longer is retried later. beets' Spotify plugin sleeps
# out whatever Retry-After a 429 names, and logs it only at debug level: on
# 2026-11-15 that was 17 hours, for one song, with the queue behind it. A
# Spotify lookup normally takes seconds, so it gets less.
import_timeout=10m
spotify_timeout=3m
# Cleared for the rest of a run once Spotify stops answering.
spotify_ok=1

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

# tag CONFIG TIME-LIMIT ATTEMPTS IMPORT-ARGS... PATH
# Returns 1 when beets or a source failed, so the caller can queue the entry
# again, and 2 when that was the last attempt.
# Sets timed_out when the import ran over its time.
tag() {
	local cfg=$1 limit=$2 attempts=$3 path=${*: -1} out status=0 retry=0
	shift 3
	timed_out=0
	out=$(timeout --kill-after=1m "$limit" \
		beet -c "$cfg" import -q "$@" 2>&1) || status=$?
	printf '%s\n' "$out"
	if ((status == 124 || status == 137)); then
		echo "beets took longer than $limit on $path" >&2
		timed_out=1
		retry=1
	elif ((status != 0)) || grep -q 'Error searching\|Max retries exceeded' <<<"$out"; then
		# beets exits 0 when a source failed but the import went on.
		retry=1
	fi
	# Lyrics and genres found for a file kept as-is stay in beets' database
	# unless written out explicitly. Its output would list every changed
	# field, whole lyrics included.
	if ! beet write "path:$path" >/dev/null; then
		echo "could not write tags of $path" >&2
		retry=1
	fi
	if ((retry)); then
		return $((attempts < max_attempts ? 1 : 2))
	fi
}

# tag_track ATTEMPTS SPOTIFY-ID PATH
# The exact Spotify track while Spotify answers; otherwise like any song.
tag_track() {
	local attempts=$1 id=$2 path=$3 status=0
	if ((spotify_ok)); then
		tag "$BEETS_SPOTIFY_CONFIG" "$spotify_timeout" "$attempts" \
			-s --search-id "$id" "$path" || status=$?
		if ((!timed_out)); then
			if ((status == 0)); then
				drop_stale_ids "$path"
			fi
			return "$status"
		fi
		echo "Spotify is not answering; the rest of this run goes without it" >&2
		spotify_ok=0
	fi
	tag "$BEETS_CONFIG" "$import_timeout" "$attempts" -s "$path"
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
touch "$work"

# fd 3: beets must not read the work list from stdin.
# shellcheck disable=SC2094 # sed -i writes a new file; fd 3 keeps the old one
while IFS=$'\t' read -r -u 3 kind uri path attempts; do
	attempts=$((${attempts:-0} + 1))
	# Files inside an album download have no URI of their own; the album
	# entry tags them together.
	if [[ -e $path && ($kind != track || $uri == spotify:track:*) ]]; then
		status=0
		case $kind in
		album) tag "$BEETS_CONFIG" "$import_timeout" "$attempts" "$path" ;;
		single) tag "$BEETS_CONFIG" "$import_timeout" "$attempts" -s "$path" ;;
		track) tag_track "$attempts" "${uri##*:}" "$path" ;;
		esac || status=$?
		if ((status == 1)); then
			printf '%s\t%s\t%s\t%s\n' "$kind" "$uri" "$path" "$attempts" |
				flock "$lock" tee -a "$queue" >/dev/null
		elif ((status != 0)); then
			echo "giving up on $path after $attempts attempts; listed in $failed" >&2
			printf '%s\t%s\t%s\n' "$kind" "$uri" "$path" >>"$failed"
		fi
	fi
	# Done with this entry: a stopped run resumes after it, not from the top.
	# fd 3 still reads the old file, which sed replaces rather than edits.
	sed -i 1d "$work"
done 3<"$work"
rm -f "$work"

# {{{ Playlists
# Songs sockseek listed as failed may be in the library after all; see
# spotify-sync-resolve.py. Every run, since a sync may have rewritten a
# playlist with nothing new to tag. The lock keeps spotify-sync from
# replacing a playlist meanwhile.
shopt -s nullglob
playlists=("$playlist_dir"/*.m3u)
if ((${#playlists[@]})); then
	flock "$STATE_DIR/playlists.lock" \
		spotify-sync-resolve "$BEETSDIR/library.db" "${playlists[@]}"
fi
# Mixes per artist and genre, as smart playlists Navidrome fills itself; see
# spotify-sync-mixes.py. They read the playlists just resolved.
flock "$STATE_DIR/playlists.lock" \
	spotify-sync-mixes "$BEETSDIR/library.db" "$playlist_dir"
# }}}

# {{{ Report
if [[ -s $failed ]]; then
	echo "$(wc -l <"$failed") entries beets gave up on are listed in $failed" >&2
fi
spotify-sync-covers "$MUSIC_DIR" "$STATE_DIR/missing-covers"
# }}}
