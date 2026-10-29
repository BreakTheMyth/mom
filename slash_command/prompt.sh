#!/bin/sh

[ -n "$PROMPT_SH" ] && return 0
PROMPT_SH=1

for prompt in prompt/*.json; do
    jq 'empty' "$prompt" || continue

    eval 'function slash_prompt_'$(basename $prompt .json)'() {
        jq -n \
            --argjson messages "$(cat $session/messages.json)" \
            --argjson prompt   "$(cat '$prompt')" \
            "\$messages + \$prompt" > "$session/messages.json"

        cd "$session"
        git add .
        cd "$MOMSPACE"

        echo
        session_history "'$prompt'"

        content=
        line=
    }'
done