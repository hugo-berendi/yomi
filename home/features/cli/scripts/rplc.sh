 #!/usr/bin/env bash

# Check if enough arguments are passed
if [ "$#" -lt 2 ]; then
  echo "Usage: replace-in-files <search-pattern> <replace-pattern> [directory]"
  exit 1
fi

# Assign arguments to variables
search=$1
replace=$2
dir=${3:-.}  # Default to the current directory if no directory is provided

# Use fd and sd to replace text
fd -t f "$dir" -x sd "$search" "$replace" {}
