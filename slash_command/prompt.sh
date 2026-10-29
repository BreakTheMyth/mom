#!/bin/sh

[ -n "$PROMPT_SH" ] && return 0
PROMPT_SH=1

for prompt in prompt/*.json; do
    jq 'empty' "$prompt" || continue

    eval 'function slash_prompt_'$(basename $prompt .json)'() {
        jq -n                                                            \
            --slurpfile messages "$session/messages.json"                \
            --slurpfile prompt   "'$prompt'"                             \
            "\$messages[0] + \$prompt[0]" > "$session/messages.json.tmp" \
        && mv "$session/messages.json.tmp" "$session/messages.json"

        cd "$session"
        git add .
        cd "$MOMSPACE"

        echo
        session_history "'$prompt'"

        content=
        line=
    }'
done