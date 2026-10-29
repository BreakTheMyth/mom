#!/bin/sh

[ -n "$CHAT_SH" ] && return 0
CHAT_SH=1

source ./style.sh
source ./slash_command/url.sh
source ./slash_command/model.sh

function chat_handle_toolcalling() {
    tool_calls=$(echo "$message" | jq '.tool_calls')
    length=$(echo "$tool_calls" | jq 'length')

    echo "$tool_calls" | jq -c '.[].function | {name, arguments}'

    for ((i=0; i < length; i++)); do
        tool_call_id=$(echo "$tool_calls" | jq -r ".[$i].id")
        tool_call_type=$(echo "$tool_calls" | jq -r ".[$i].type")

        [ $tool_call_type != 'function' ] && return 1

        tool_name=$(echo "$tool_calls" | jq -r ".[$i].function.name")
        tool_args=$(echo "$tool_calls" | jq \
            ".[$i].function.arguments | fromjson")

        "$tool_name"_call "$tool_args"

        [ $? -eq 0 ] && tool_status="success" || tool_status="error"

        tool_content=$(jq -nc           \
            --arg status "$tool_status" \
            --arg result "$tool_result" \
            '{status: $status, result: $result}')

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

    return 0
}

function chat_recv_messages() {
    while true; do
        prompt=$(cat $session/prompt.json)
        body=$(jq -nc                      \
            --arg     model    "$model"    \
            --argjson prompt   "$prompt"   \
            --argjson messages "$messages" \
            --argjson tools    "$tools"    \
            '{
                model: $model,
                messages: $prompt + $messages,
                stream: false,
                tools: $tools
            }')

        response=$(curl -s "$chat_url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $api_key" \
            -d "$body")

        [ -z "$response" ] && return 1

        message=$(echo "$response" | jq '.choices[0].message')
        finish_reason=$(echo "$response" \
            | jq -r '.choices[0].finish_reason')

        if [ "$message" == 'null' ]; then
            style_red
            echo "$response" >&2
            style_resume
            return 1
        fi

        content=$(echo "$message" | jq -r '.content')
        reasoning_content=$(echo "$message" \
            | jq -r '.reasoning_content')

        style_faint_italic
        [ -n "$reasoning_content" ] && echo "$reasoning_content"
        style_resume
        style_bold
        [ -n "$content" ] && echo "$content"
        style_resume

        messages=$(cat "$session/messages.json" | jq -c \
            --argjson message "$message" \
            '. += [$message]')

        echo "$messages" | jq . > "$session/messages.json"

        cd "$session"
        git add .
        cd "$MOMSPACE"

        [ "$finish_reason" == 'stop' ] && break

        if [ "$finish_reason" != 'tool_calls' ]; then
            style_red
            echo "$response" >&2
            style_resume
            return 1
        fi

        chat_handle_toolcalling
    done

    cd "$session"
    git -c user.name="$(whoami)"            \
        -c user.email="$(whoami)@localhost" \
        commit -m "$1" > /dev/null
    cd "$MOMSPACE"

    return 0
}

function chat_send_messages() {
    [ -z "$1" ] && return 0

    slash_retry || true

    messages=$(cat "$session/messages.json" | jq -c \
        --arg content "$1" \
        '. += [{
            "role": "user",
            "content": $content
        }]')

    echo "$messages" | jq . > "$session/messages.json"

    chat_recv_messages "$1"

    return 0
}

function chat_retry() {
    [ -z "$session" ] && return 1

    messages=$(cat "$session/messages.json" | jq .)
    message=$(echo "$messages" | jq '.[-1]')
    role=$(echo "$message" | jq -r '.role')

    content=$(echo "$messages" \
        | jq -r 'map(select(.role == "user"))[-1].content')

    if [ "$role" == 'tool' ]; then
        cd "$session"
        git restore .
        cd "$MOMSPACE"

        messages=$(cat "$session/messages.json" | jq .)
        message=$(echo "$messages" | jq '.[-1]')
        role=$(echo "$message" | jq -r '.role')
    fi

    [ "$role" == 'user' ] && \
        chat_recv_messages "$content" && \
        return 0

    [ "$role" != 'assistant' ] && return 1

    tool_calls=$(echo "$message" | jq '.tool_calls')
    length=$(echo "$tool_calls" | jq 'length')

    [ "$length" -eq 0 ] && return 0

    for ((i=0; i < length; i++)); do
        tool_call_id=$(echo "$tool_calls" | jq -r ".[$i].id")
        tool_call_type=$(echo "$tool_calls" | jq -r ".[$i].type")

        [ $tool_call_type != 'function' ] && return 1

        messages=$(cat "$session/messages.json" | jq -c \
            --arg content "Tool execution interrupted" \
            --arg id      "$tool_call_id" \
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

    return 0
}