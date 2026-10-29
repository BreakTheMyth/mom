#!/bin/sh

[ -n "$RETRY_SH" ] && return 0
RETRY_SH=1

source ./chat.sh

function slash_retry() {
    [ -z "$session" ] && return 1

    cd "$session"
    git restore .
    cd "$MOMSPACE"

    role=$(jq -r '.[-1].role' "$session/messages.json")

    content=$(jq -r 'map(select(.role == "user"))[-1].content' \
        "$session/messages.json")

    if [ "$content" == 'null' ]; then
        content=
        return 1
    fi

    if [ "$role" == 'tool' ] || [ "$role" == 'user' ]; then
        chat_recv_messages "$content"
        content=
        return 0
    fi

    [ "$role" != 'assistant' ] && return 1

    message_index=$(jq 'length - 1' "$session/messages.json")
    length=$(jq ".[$message_index].tool_calls | length" \
        "$session/messages.json")

    if [ "$length" -eq 0 ]; then
        content=
        return 0
    fi

    for ((i=0; i < length; i++)); do
        tool_call_id=$(jq -r ".[$message_index].tool_calls[$i].id" \
            "$session/messages.json")
        tool_call_type=$(jq -r ".[$message_index].tool_calls[$i].type" \
            "$session/messages.json")

        [ $tool_call_type != 'function' ] && return 1

        tool_content=$(jq -nc '{status: "unknown", result: null}')

        jq -n                                             \
            --slurpfile messages "$session/messages.json" \
            --arg id      "$tool_call_id"                 \
            --arg content "$tool_content"                 \
            '$messages[0] + [{
                "role": "tool",
                "tool_call_id": $id,
                "content": $content
            }]' > "$session/messages.json.tmp" \
        && mv "$session/messages.json.tmp" "$session/messages.json"
    done

    cd "$session"
    git add .
    cd "$MOMSPACE"

    chat_recv_messages "$content"
    content=
    return 0
}