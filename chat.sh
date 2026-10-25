#!/bin/sh

[ -n "$CHAT_SH" ] && return
CHAT_SH=1

source ./style.sh
source ./url.sh
source ./model.sh

function chat_create_session() {
    mkdir -p session

    while true; do
        echo -n "session_name: "

        style_pink
        IFS= read -r session_name
        style_resume

        if [ -z "$session_name" ]; then
            style_red
            echo "session_name cannot be empty"
            style_resume

            continue
        fi

        session="session/$session_name"

        if [ -e "$session" ]; then
            style_red
            echo "$session already existed"
            style_resume

            continue
        fi

        break

    done

    mkdir -p "$session"

    jq -n --arg content "$(cat prompt/system)" \
        '[{role:"system",content:$content}]' \
        > "$session/messages.json"

    cd "$session"
    git init -b main
    git add .
    git -c user.name="$(whoami)" \
        -c user.email="$(whoami)@localhost" \
        commit -m "first commit"
    cd "$WORKSPACE/$MOMSPACE"
}

function chat_select_session() {
    mkdir -p session

    session=$(dirname \
        $(find session \
            -mindepth 2 \
            -maxdepth 2 \
            -type f \
            -name 'messages.json' \
            | fzf \
        ) \
        2>/dev/null \
    )

    if [ -z "$session" ]; then
        chat_create_session
        return
    fi

    messages=$(cat "$session/messages.json" | jq .)
    length=$(echo "$messages" | jq 'length')

    for ((i=0; i < length; i++)); do
        message=$(echo "$messages" | jq ".[$i]")
        role=$(echo "$message" | jq -r '.role')

        if [ "$role" == 'user' ]; then
            content=$(echo "$message" | jq -r '.content')
            style_pink
            echo "$content"
            style_resume
            continue
        fi

        [ "$role" == 'tool'      ] && continue
        [ "$role" == 'system'    ] && continue
        [ "$role" != 'assistant' ] && exit

        content=$(echo "$message" | jq -r '.content')
        reasoning_content=$(echo "$message" | jq -r '.reasoning_content')
        tool_calls=$(echo "$message" | jq -r '.tool_calls')

        style_faint_italic
        [ -n "$reasoning_content" ] && echo "$reasoning_content"
        style_resume
        style_bold
        [ -n "$content" ] && echo "$content"
        style_resume
        [ -n "$tool_calls" ] && echo "$tool_calls" | jq -c '.[].function | {name, arguments}'

    done
}

function chat_delete_session() {
    chat_select_session

    rm -rf "$session"

    chat_select_session
}

function chat_rename_session() {
    chat_select_session

    session="$session"

    while true; do
        echo -n "new session_name: "

        style_pink
        read session_name
        style_resume

        if [ -z "$session_name" ]; then
            style_red
            echo "session_name cannot be empty"
            style_resume

            continue
        fi

        session="session/$session_name"

        if [ -e "$session" ]; then
            style_red
            echo "$session already existed"
            style_resume

            continue
        fi

        break

    done

    mv "$session" "session/$session_name"

    session="session/$session_name"
}

tools='[]'

function tool_load() {

    for tool in ./tool/*.sh; do
        source "$tool"

        tool_name=$(basename "$tool" .sh)
        tool_desc=$("$tool_name"_desc)

        style_blue
        echo "Loading tool/$tool_name"
        style_resume

        "$tool_name"_init

        tools=$(echo "$tools" | jq \
            --argjson tool_desc "$tool_desc" \
            '. += [$tool_desc]')
    done
}

function tool_unload() {
    for tool_name in $(echo "$tools" | jq -r '.[].function.name'); do
        style_blue
        echo "Unloading tool/$tool_name"
        style_resume

        "$tool_name"_exit

        unset -f "$tool_name"_desc
        unset -f "$tool_name"_init
        unset -f "$tool_name"_exit
        unset -f "$tool_name"_call
    done

    tools='[]'
}

function chat_handle_toolcalling() {
    tool_calls=$(echo "$message" | jq '.tool_calls')
    length=$(echo "$tool_calls" | jq 'length')

    echo "$tool_calls" | jq -c '.[].function | {name, arguments}'

    for ((i=0; i < length; i++)); do
        tool_call_id=$(echo "$tool_calls" | jq -r ".[$i].id")
        tool_call_type=$(echo "$tool_calls" | jq -r ".[$i].type")

        [ $tool_call_type != 'function' ] && exit

        tool_name=$(echo "$tool_calls" | jq -r ".[$i].function.name")
        tool_args=$(echo "$tool_calls" | jq ".[$i].function.arguments | fromjson")

        "$tool_name"_call "$tool_args"

        messages=$(cat "$session/messages.json" | jq -c \
            --arg content "$tool_retval" \
            --arg id      "$tool_call_id" \
            '. += [{"role": "tool", "tool_call_id": $id, "content": $content}]')

        echo "$messages" | jq . > "$session/messages.json"
    done

    cd "$session"
    git add .
    cd "$WORKSPACE/$MOMSPACE"
}

function chat_send_messages() {
    messages=$(cat "$session/messages.json" | jq -c \
        --arg content "$1" \
        '. += [{"role": "user", "content": $content}]')

    echo "$messages" | jq . > "$session/messages.json"

    while true; do
        body=$(jq -nc \
            --arg model "$model" \
            --argjson messages "$messages" \
            --argjson tools "$tools" \
            '{
                model: $model,
                messages: $messages,
                stream: false,
                tools: $tools
            }')

        response=$(curl -s "$chat_url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $api_key" \
            -d "$body")

        [ -z "$response" ] && exit

        message=$(echo "$response" | jq '.choices[0].message')
        finish_reason=$(echo "$response" | jq -r '.choices[0].finish_reason')

        if [ "$message" == 'null' ]; then
            style_red
            echo "$response"
            style_resume
            exit
        fi

        content=$(echo "$message" | jq -r '.content')
        reasoning_content=$(echo "$message" | jq -r '.reasoning_content')

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
        cd "$WORKSPACE/$MOMSPACE"

        [ "$finish_reason" == 'stop'       ] && break
        [ "$finish_reason" != 'tool_calls' ] && exit

        chat_handle_toolcalling "$message"
    done

    cd "$session"
    git status
    git -c user.name="$(whoami)" \
        -c user.email="$(whoami)@localhost" \
        commit -m "$1"
    cd "$WORKSPACE/$MOMSPACE"
}