#!/bin/sh

[ -n "$PROMPT_SH" ] && return 0
PROMPT_SH=1

source ./style.sh

for prompt in prompt/*.md; do
    eval 'function slash_prompt_'$(basename $prompt .md)'() {
        content="$content"$'\n'"$line$(cat $prompt)"
        line=

        style_pink
        cat "$prompt"
        style_resume
        echo
    }'
done