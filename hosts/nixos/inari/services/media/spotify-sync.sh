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

# Tracks Soulseek did not have are searched again once a day, not on every
# run; a large library would otherwise repeat the same failing searches
# every quarter of an hour.
retry_stamp=$STATE_DIR/last-full-retry
skip_flags=(--skip-not-found)
if [[ ! -e $retry_stamp || -n $(find "$retry_stamp" -mmin +1440) ]]; then
	skip_flags=()
fi

failed=0

# sync INPUT INDEX-NAME [M3U-NAME] [EXTRA-SOCKSEEK-ARGS...]
sync() {
	local args=(
		"$1" --config "$SOCKSEEK_CONFIG" --output-dir "$MUSIC_DIR"
		--index-path "$STATE_DIR/$2.index" "${skip_flags[@]}"
	)
	if [[ -n ${3:-} ]]; then
		args+=(--write-playlist --playlist-path "$playlist_dir/$3.m3u")
	fi
	args+=("${@:4}")
	echo "syncing ${3:-$2}"
	if ! sockseek "${args[@]}"; then
		echo "sync of ${3:-$2} failed" >&2
		failed=1
	fi
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

# id <TAB> name for every playlist the account owns or collaborates on. Since
# February 2026 the API returns no tracks for anyone else's playlists, so
# followed playlists are left out on purpose.
owned=""
next="me/playlists?limit=50"
while [[ -n $next ]]; do
	page=$(api "$next")
	owned+=$(jq -r --arg me "$me" '
		.items[]
		| select(. != null and (.owner.id == $me or .collaborative))
		| [.id, (.name | gsub("[/\\t\\n\\r]"; "-") | sub("^[.]+"; ""))]
		| @tsv' <<<"$page")$'\n'
	next=$(jq -r '.next // empty | sub("^https://api.spotify.com/v1/"; "")' <<<"$page")
done
# }}}

declare -A written=()

sync spotify-likes likes Lieblingssongs
written[Lieblingssongs]=1

# Whole albums, without a playlist file: Navidrome lists them as albums anyway.
sync spotify-albums albums "" --name-format "$ALBUM_NAME_FORMAT"

while IFS=$'\t' read -r id name; do
	[[ -n $id ]] || continue
	[[ -n $name ]] || name=$id
	# Two playlists of the same name would write the same .m3u.
	[[ -z ${written[$name]:-} ]] || name="$name ($id)"
	sync "https://open.spotify.com/playlist/$id" "playlist-$id" "$name"
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
