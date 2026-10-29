#!/bin/sh

[ -n "$RETRY_SH" ] && return 0
RETRY_SH=1

source ./chat.sh

function slash_retry() {
    [ -z "$session" ] && return 1

    cd "$session"
    git restore .
    cd "$MOMSPACE"

    messages=$(cat "$session/messages.json" | jq .)
    message=$(echo "$messages" | jq '.[-1]')
    role=$(echo "$message" | jq -r '.role')

    content=$(echo "$messages" \
        | jq -r 'map(select(.role == "user"))[-1].content')

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

    tool_calls=$(echo "$message" | jq '.tool_calls')
    length=$(echo "$tool_calls" | jq 'length')

    if [ "$length" -eq 0 ]; then
        content=
        return 0
    fi

    for ((i=0; i < length; i++)); do
        tool_call_id=$(echo "$tool_calls" | jq -r ".[$i].id")
        tool_call_type=$(echo "$tool_calls" | jq -r ".[$i].type")

        [ $tool_call_type != 'function' ] && return 1

        tool_content=$(jq -nc '{status: "unknown", result: null}')

        messages=$(cat "$session/messages.json" | jq -c \
            --arg id      "$tool_call_id"               \
            --arg content "$tool_content"               \
            '. += [{
                "role": "tool", 
                "tool_call_id": $id, 
                "content": $content
            }]')

        echo "$messages" | jq . > "$session/messages.json"
    done

    cd "$session"
    git add .
    cd "$MOMSPACE"

    chat_recv_messages "$content"
    content=
    return 0
}