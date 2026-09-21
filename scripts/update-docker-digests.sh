#!/usr/bin/env bash
# Refreshes `image = "repo:tag@sha256:...";` pins in oci-containers definitions
# to whatever digest the registry currently serves for that tag. Digests are
# pinned (not the bare tag) for reproducibility/security, so nothing moves
# until this runs; there is no runtime auto-update.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

token_for() {
	local registry="$1" repo="$2"
	if [[ "$registry" == "ghcr.io" ]]; then
		curl -fsSL "https://ghcr.io/token?service=ghcr.io&scope=repository:${repo}:pull" | jq -r '.token'
	else
		curl -fsSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${repo}:pull" | jq -r '.token'
	fi
}

digest_for() {
	local registry="$1" repo="$2" tag="$3" token
	token=$(token_for "$registry" "$repo")
	curl -fsSL \
		-H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
		-H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
		-H "Accept: application/vnd.oci.image.manifest.v1+json" \
		-H "Accept: application/vnd.oci.image.index.v1+json" \
		-D - -o /dev/null \
		"https://${registry}/v2/${repo}/manifests/${tag}" |
		tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}'
}

mapfile -t files < <(grep -rlE 'image = "[^"]+@sha256:[a-f0-9]{64}"' --include='*.nix' hosts modules)

any_changed=0
for file in "${files[@]}"; do
	file_changed=0
	mapfile -t refs < <(grep -ohE '"[^"]+@sha256:[a-f0-9]{64}"' "$file" | tr -d '"' | sort -u)
	for ref in "${refs[@]}"; do
		imageTag="${ref%@sha256:*}"
		oldDigest="${ref##*@sha256:}"

		firstSegment="${imageTag%%/*}"
		if [[ "$imageTag" == */* && ("$firstSegment" == *.* || "$firstSegment" == *:*) ]]; then
			registry="$firstSegment"
			repoWithTag="${imageTag#*/}"
		else
			registry="registry-1.docker.io"
			repoWithTag="$imageTag"
			[[ "$repoWithTag" == */* ]] || repoWithTag="library/${repoWithTag}"
		fi

		if [[ "$repoWithTag" == *:* ]]; then
			repo="${repoWithTag%:*}"
			tag="${repoWithTag##*:}"
		else
			repo="$repoWithTag"
			tag="latest"
		fi

		newDigest=$(digest_for "$registry" "$repo" "$tag" || true)
		newDigest="${newDigest#sha256:}"

		if [[ -z "$newDigest" ]]; then
			echo "warn: could not resolve digest for ${repo}:${tag}, leaving as is" >&2
			continue
		fi

		if [[ "$newDigest" != "$oldDigest" ]]; then
			echo "update: ${repo}:${tag}  ${oldDigest} -> ${newDigest}  (${file})"
			sed -i "s|${oldDigest}|${newDigest}|" "$file"
			file_changed=1
		fi
	done

	if [[ "$file_changed" == 1 ]]; then
		any_changed=1
	fi
done

exit_code=0
if [[ "$any_changed" == 1 ]]; then
	if ! nix build --no-link '.#nixosConfigurations.inari.config.system.build.toplevel'; then
		echo "eval failed after digest updates, run 'git diff -- hosts modules' and revert what's broken" >&2
		exit_code=1
	fi
fi

exit "$exit_code"
