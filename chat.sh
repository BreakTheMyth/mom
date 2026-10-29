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

    return 0
}

function chat_recv_messages() {
    while true; do
        body=$(jq -nc                                     \
            --arg       model    "$model"                 \
            --slurpfile prompt   "$session/prompt.json"   \
            --slurpfile messages "$session/messages.json" \
            --argjson   tools    "$tools"                 \
            '{
                model: $model,
                messages: $prompt[0] + $messages[0],
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

        jq -n                                                          \
            --slurpfile messages "$session/messages.json"              \
            --argjson   message  "$message"                            \
            '$messages[0] + [$message]' > "$session/messages.json.tmp" \
        && mv "$session/messages.json.tmp" "$session/messages.json"

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

    jq -n                                             \
        --slurpfile messages "$session/messages.json" \
        --arg       content "$1"                      \
        '$messages[0] + [{
            "role": "user",
            "content": $content
        }]' > "$session/messages.json.tmp"            \
    && mv "$session/messages.json.tmp" "$session/messages.json"

    chat_recv_messages "$1"

    return 0
}

function chat_retry() {
    [ -z "$session" ] && return 1

    role=$(jq -r '.[-1].role' "$session/messages.json")

    content=$(jq -r 'map(select(.role == "user"))[-1].content' \
        "$session/messages.json")

    if [ "$role" == 'tool' ]; then
        cd "$session"
        git restore .
        cd "$MOMSPACE"

        role=$(jq -r '.[-1].role' "$session/messages.json")
    fi

    [ "$role" == 'user' ] && \
        chat_recv_messages "$content" && \
        return 0

    [ "$role" != 'assistant' ] && return 1

    message_index=$(jq 'length - 1' "$session/messages.json")
    length=$(jq ".[$message_index].tool_calls | length" \
        "$session/messages.json")

    [ "$length" -eq 0 ] && return 0

    for ((i=0; i < length; i++)); do
        tool_call_id=$(jq -r ".[$message_index].tool_calls[$i].id" \
            "$session/messages.json")
        tool_call_type=$(jq -r ".[$message_index].tool_calls[$i].type" \
            "$session/messages.json")

        [ $tool_call_type != 'function' ] && return 1

        jq -n                                                 \
            --slurpfile messages "$session/messages.json"     \
            --arg       content  "Tool execution interrupted" \
            --arg       id       "$tool_call_id"              \
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

    return 0
}