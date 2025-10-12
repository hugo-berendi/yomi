{pkgs, ...}: let
	yk-enc = pkgs.writeShellScriptBin "yk-enc" ''
		#!/usr/bin/env bash

		set -euo pipefail

		show_usage() {
			cat <<EOF
		Usage: $(basename "$0") [OPTIONS] <input_file>

		Encrypt a file using YubiKey-backed AGE encryption.

		OPTIONS:
		  -o, --output FILE    Output file (default: input_file.age)
		  -r, --recipient ID   YubiKey recipient ID (can specify multiple)
		  -a, --armor          ASCII armor the output
		  -h, --help           Show this help message

		ENVIRONMENT:
		  YOMI_YUBI_AGE_RECIPIENTS    Comma-separated list of default recipients

		EXAMPLES:
		  $(basename "$0") secret.txt
		  $(basename "$0") -o encrypted.age secret.txt
		  $(basename "$0") -r age1yubikey1... -r age1yubikey2... secret.txt

EOF
		}

		recipients=()
		output=""
		armor=false
		input=""

		while [[ $# -gt 0 ]]; do
			case $1 in
				-o|--output)
					output="$2"
					shift 2
					;;
				-r|--recipient)
					recipients+=("$2")
					shift 2
					;;
				-a|--armor)
					armor=true
					shift
					;;
				-h|--help)
					show_usage
					exit 0
					;;
				*)
					if [[ -z "$input" ]]; then
						input="$1"
					else
						echo "Error: Unexpected argument: $1" >&2
						show_usage
						exit 1
					fi
					shift
					;;
			esac
		done

		if [[ -z "$input" ]]; then
			echo "Error: No input file specified" >&2
			show_usage
			exit 1
		fi

		if [[ ! -f "$input" ]]; then
			echo "Error: Input file not found: $input" >&2
			exit 1
		fi

		if [[ ''${#recipients[@]} -eq 0 ]]; then
			if [[ -n "''${YOMI_YUBI_AGE_RECIPIENTS:-}" ]]; then
				IFS=',' read -ra recipients <<< "$YOMI_YUBI_AGE_RECIPIENTS"
			else
				echo "Error: No recipients specified. Use -r or set YOMI_YUBI_AGE_RECIPIENTS" >&2
				exit 1
			fi
		fi

		if [[ -z "$output" ]]; then
			output="''${input}.age"
		fi

		recipient_args=()
		for r in "''${recipients[@]}"; do
			recipient_args+=("-r" "$r")
		done

		if [[ "$armor" == true ]]; then
			recipient_args+=("-a")
		fi

		echo "Encrypting $input to $output with ''${#recipients[@]} recipient(s)..." >&2
		echo "Touch your YubiKey when it blinks..." >&2

		${pkgs.rage}/bin/rage "''${recipient_args[@]}" -o "$output" "$input"

		echo "Encrypted successfully: $output" >&2
	'';

	yk-decrypt = pkgs.writeShellScriptBin "yk-decrypt" ''
		#!/usr/bin/env bash

		set -euo pipefail

		show_usage() {
			cat <<EOF
		Usage: $(basename "$0") [OPTIONS] <input_file>

		Decrypt a file encrypted with YubiKey-backed AGE encryption.

		OPTIONS:
		  -o, --output FILE    Output file (default: strip .age extension or stdout)
		  -i, --identity FILE  Identity file to use (default: YubiKey plugin)
		  -h, --help           Show this help message

		EXAMPLES:
		  $(basename "$0") secret.txt.age
		  $(basename "$0") -o secret.txt encrypted.age
		  $(basename "$0") secret.age > decrypted.txt

EOF
		}

		output=""
		identity_file=""
		input=""

		while [[ $# -gt 0 ]]; do
			case $1 in
				-o|--output)
					output="$2"
					shift 2
					;;
				-i|--identity)
					identity_file="$2"
					shift 2
					;;
				-h|--help)
					show_usage
					exit 0
					;;
				*)
					if [[ -z "$input" ]]; then
						input="$1"
					else
						echo "Error: Unexpected argument: $1" >&2
						show_usage
						exit 1
					fi
					shift
					;;
			esac
		done

		if [[ -z "$input" ]]; then
			echo "Error: No input file specified" >&2
			show_usage
			exit 1
		fi

		if [[ ! -f "$input" ]]; then
			echo "Error: Input file not found: $input" >&2
			exit 1
		fi

		if [[ -z "$output" ]]; then
			if [[ "$input" == *.age ]]; then
				output="''${input%.age}"
			else
				output="-"
			fi
		fi

		identity_args=()
		if [[ -n "$identity_file" ]]; then
			identity_args+=("-i" "$identity_file")
		else
			identity_args+=("-i" "age-plugin-yubikey")
		fi

		if [[ "$output" != "-" ]]; then
			echo "Decrypting $input to $output..." >&2
		fi
		echo "Touch your YubiKey when it blinks..." >&2

		${pkgs.rage}/bin/rage -d "''${identity_args[@]}" -o "$output" "$input"

		if [[ "$output" != "-" ]]; then
			echo "Decrypted successfully: $output" >&2
		fi
	'';
in {
	home.packages = [yk-enc yk-decrypt];
}
