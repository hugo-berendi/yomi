#!/usr/bin/env bash
# Mirrors the Spotify library into the music folder over Soulseek: liked songs,
# saved albums, and every playlist the account owns or collaborates on. Liked
# songs and playlists also become .m3u files that Navidrome imports.
#
# Set by spotify-sync.nix: MUSIC_DIR, STATE_DIR, SOCKSEEK_CONFIG,
# ALBUM_NAME_FORMAT, and the client-id, client-secret and refresh-token
# credentials. Tagging happens afterwards in spotify-sync-tag.sh.
set -euo pipefail

creds=$CREDENTIALS_DIRECTORY
playlist_dir=$MUSIC_DIR/playlists
fingerprints=$STATE_DIR/fingerprints
mkdir -p "$fingerprints"

# Every sockseek call is a fresh Soulseek login. One call per playlist every
# quarter of an hour came to 36 logins in 29 minutes on 2026-11-15, after
# which the server stopped answering the Mullvad address. So a source is only
# fetched again when Spotify reports a change, and logins are spaced out.
login_gap=60
last_login=-$login_gap

# Tracks Soulseek did not have are searched again once a day, not on every
# run; that daily run also goes through every source, changed or not.
retry_stamp=$STATE_DIR/last-full-retry
skip_flags=(--skip-not-found)
if [[ ! -e $retry_stamp || -n $(find "$retry_stamp" -mmin +1440) ]]; then
	skip_flags=()
fi

failed=0

# sync INPUT STATE-NAME FINGERPRINT [M3U-NAME] [EXTRA-SOCKSEEK-ARGS...]
sync() {
	local label=${4:-$2} stamp=$fingerprints/$2 log=$STATE_DIR/sockseek.log
	if ((${#skip_flags[@]})) && [[ -e $stamp && $(<"$stamp") == "$3" ]] &&
		[[ -z ${4:-} || -e $playlist_dir/$4.m3u ]]; then
		return
	fi

	local args=(
		"$1" --config "$SOCKSEEK_CONFIG" --output-dir "$MUSIC_DIR"
		--index-path "$STATE_DIR/$2.index" "${skip_flags[@]}"
	)
	if [[ -n ${4:-} ]]; then
		args+=(--write-playlist --playlist-path "$playlist_dir/$4.m3u")
	fi
	args+=("${@:5}")

	local wait=$((last_login + login_gap - SECONDS))
	((wait <= 0)) || sleep "$wait"
	last_login=$SECONDS

	echo "syncing $label"
	local pid status=0
	sockseek "${args[@]}" >"$log" 2>&1 &
	pid=$!
	tail -n +1 -f --pid="$pid" "$log" &
	# sockseek retries a failed login forever, every few seconds. That is
	# exactly what keeps a ban going, so the run stops at the first failure.
	while kill -0 "$pid" 2>/dev/null; do
		if grep -q 'Initial Soulseek login failed' "$log"; then
			kill "$pid"
			wait || true
			echo "Soulseek login failed; stopping until the next run" >&2
			exit 1
		fi
		sleep 5
	done
	wait "$pid" || status=$?
	wait

	# sockseek also exits 1 when a single song was not on Soulseek. That is
	# routine, and is retried daily; only a run that never got to its summary
	# (Spotify unreachable, crash) fails the unit. A source with nothing new
	# exits 0 without a summary.
	if ((status != 0)); then
		if ! grep -q '^\[cli\] Completed:' "$log"; then
			echo "sync of $label failed" >&2
			failed=1
			return
		fi
		echo "some songs of $label were not found"
	fi
	printf '%s\n' "$3" >"$stamp"
}

# {{{ Spotify API
# Secrets go to curl through stdin, never through its arguments.
access_token=$(
	printf 'user = "%s:%s"\n' "$(<"$creds/client-id")" "$(<"$creds/client-secret")" |
		curl -sSf --max-time 30 -K - \
			--data-urlencode grant_type=refresh_token \
			--data-urlencode "refresh_token@$creds/refresh-token" \
			https://accounts.spotify.com/api/token |
		jq -r .access_token
)

api() {
	printf 'header = "Authorization: Bearer %s"\n' "$access_token" |
		curl -sSf --max-time 30 -K - "https://api.spotify.com/v1/$1"
}

me=$(api me | jq -r .id)

# Liked songs and saved albums have no snapshot; their count and the newest
# addition change whenever something is added or removed.
newest() { api "$1?limit=1" | jq -r '"\(.total) \(.items[0].added_at // "")"'; }

# id <TAB> snapshot <TAB> name for every playlist the account owns or
# collaborates on. Since February 2026 the API returns no tracks for anyone
# else's playlists, so followed playlists are left out on purpose.
owned=""
next="me/playlists?limit=50"
while [[ -n $next ]]; do
	page=$(api "$next")
	owned+=$(jq -r --arg me "$me" '
		.items[]
		| select(. != null and (.owner.id == $me or .collaborative))
		| [.id, .snapshot_id, (.name | gsub("[/\\t\\n\\r]"; "-") | sub("^[.]+"; ""))]
		| @tsv' <<<"$page")$'\n'
	next=$(jq -r '.next // empty | sub("^https://api.spotify.com/v1/"; "")' <<<"$page")
done
# }}}

declare -A written=()

sync spotify-likes likes "$(newest me/tracks)" Lieblingssongs
written[Lieblingssongs]=1

# Whole albums, without a playlist file: Navidrome lists them as albums anyway.
sync spotify-albums albums "$(newest me/albums)" "" --name-format "$ALBUM_NAME_FORMAT"

while IFS=$'\t' read -r id snapshot name; do
	[[ -n $id ]] || continue
	[[ -n $name ]] || name=$id
	# Two playlists of the same name would write the same .m3u.
	[[ -z ${written[$name]:-} ]] || name="$name ($id)"
	# A rename keeps the snapshot but needs a new .m3u.
	sync "https://open.spotify.com/playlist/$id" "playlist-$id" "$snapshot $name" "$name"
	written[$name]=1
done <<<"$owned"

# {{{ Cleanup
# Drop .m3u files of playlists that were deleted or renamed in Spotify. Only
# files this script wrote are touched; the manifest remembers them.
manifest=$STATE_DIR/playlists
if [[ -e $manifest ]]; then
	while IFS= read -r old; do
		if [[ -n $old && -z ${written[$old]:-} ]]; then
			echo "removing stale playlist $old"
			rm -f -- "$playlist_dir/$old.m3u"
		fi
	done <"$manifest"
fi
printf '%s\n' "${!written[@]}" >"$manifest"
# }}}

if [[ $failed -eq 0 && ${#skip_flags[@]} -eq 0 ]]; then
	touch "$retry_stamp"
fi
exit "$failed"
