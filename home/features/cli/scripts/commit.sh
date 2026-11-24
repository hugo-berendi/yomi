#!/usr/bin/env bash

TYPE=$(gum choose "fix" "feat" "docs" "style" "refactor" "test" "chore" "revert" "delete" --header="What kind of change?")

SCOPE=$(gum input --placeholder "scope" --header="What is the scope of this change?")

if [[ "$SCOPE" != "" ]]; then
	TYPE="$TYPE($SCOPE)"
fi

BREAKING=$(gum choose "yes" "no" --header="Is this a breaking change?")

if [[ "$BREAKING" == "yes" ]]; then
	TYPE="$TYPE!"
fi

SUMMARY=$(gum input --value "$TYPE: " --placeholder "Summary of this change" --header="What is the summary of this change?")
DESCRIPTION=$(gum write --placeholder "Details of this change" --header="What are the details of this change?")

gum confirm "Commit changes?" && git commit -S -m "$SUMMARY" -m "$DESCRIPTION"
