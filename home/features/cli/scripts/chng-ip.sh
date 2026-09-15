#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "Please run this as root" >&2
	exit 1
fi

systemctl enable --now tor.service
systemctl reload tor.service
