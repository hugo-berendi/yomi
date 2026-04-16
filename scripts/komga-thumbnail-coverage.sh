#!/usr/bin/env nix-shell
#! nix-shell -i bash -p bash curl jq gum coreutils
set -euo pipefail

KOMGA_BASE_URI="${KOMGA_BASE_URI:-http://127.0.0.1:8429}"
LIBRARY_ID="${1:-${KOMGA_LIBRARY_ID:-}}"
INTERVAL="${INTERVAL:-15}"
MISSING_FILE="/tmp/komga-missing-thumbnails.tsv"

if [[ -z "${LIBRARY_ID}" ]]; then
	printf 'Usage: %s <library-id>\n' "$(basename "$0")" >&2
	exit 1
fi

if [[ -n "${KOMGA_USER:-}" && -n "${KOMGA_PASSWORD:-}" ]]; then
	KOMGA_AUTH=(--user "${KOMGA_USER}:${KOMGA_PASSWORD}")
else
	KOMGA_USER="$(sudo sh -c "tr -d '\n' < /run/secrets/komga_user")"
	KOMGA_PASSWORD="$(sudo sh -c "tr -d '\n' < /run/secrets/komga_password")"
	KOMGA_AUTH=(--user "${KOMGA_USER}:${KOMGA_PASSWORD}")
fi

api_get() {
	curl --silent --show-error --fail "${KOMGA_AUTH[@]}" "${KOMGA_BASE_URI}$1"
}

collect_coverage() {
	local first_page total_pages p series_id series_name count tmp

	first_page="$(api_get "/api/v1/series?library_id=${LIBRARY_ID}&size=100&page=0&unpaged=false")"
	total_pages="$(printf '%s' "${first_page}" | jq -r '.totalPages')"

	tmp="$(mktemp)"
	: >"${MISSING_FILE}"

	printf '%s' "${first_page}" | jq -r '.content[] | [.id, .name] | @tsv' >"${tmp}"

	for ((p = 1; p < total_pages; p++)); do
		api_get "/api/v1/series?library_id=${LIBRARY_ID}&size=100&page=${p}&unpaged=false" |
			jq -r '.content[] | [.id, .name] | @tsv' >>"${tmp}"
	done

	total=0
	with=0
	without=0

	while IFS=$'\t' read -r series_id series_name; do
		total=$((total + 1))
		count="$(api_get "/api/v1/series/${series_id}/thumbnails" | jq 'length')"
		if [[ "${count}" -gt 0 ]]; then
			with=$((with + 1))
		else
			without=$((without + 1))
			printf '%s\t%s\n' "${series_id}" "${series_name}" >>"${MISSING_FILE}"
		fi
	done <"${tmp}"

	rm -f "${tmp}"
}

render_dashboard() {
	local now shown series_id series_name

	now="$(date '+%Y-%m-%d %H:%M:%S')"
	printf '\033c'

	gum style --border rounded --padding '0 1' --margin '1 0' "Komga Thumbnail Coverage"
	gum style "Updated: ${now}"
	gum style "Library: ${LIBRARY_ID}"
	gum style "Total: ${total}"
	gum style "With thumbnails: ${with}"
	gum style "Without thumbnails: ${without}"
	gum style "Missing list: ${MISSING_FILE}"
	printf '\n'
	gum style --foreground 212 "First 20 missing series"

	shown=0
	while IFS=$'\t' read -r series_id series_name; do
		printf '%s\t%s\n' "${series_id}" "${series_name}"
		shown=$((shown + 1))
		if [[ "${shown}" -ge 20 ]]; then
			break
		fi
	done <"${MISSING_FILE}"

	if [[ "${shown}" -eq 0 ]]; then
		gum style --foreground 10 "No missing series"
	fi
}

while true; do
	collect_coverage
	render_dashboard
	sleep "${INTERVAL}"
done
