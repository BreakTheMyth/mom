#!/bin/sh

[ -n "$SESSION_SH" ] && return 0
SESSION_SH=1

source ./style.sh

function slash_session_create() {
    mkdir -p session

    wait_for_interrupt=true

    while true; do

        echo
        echo -n "session_name: "
        style_pink
        IFS= read -r session_name || true
        style_resume

        ! $wait_for_interrupt && return 1

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

    wait_for_interrupt=false

    prompt=$(find prompt \
        -mindepth 1      \
        -maxdepth 1      \
        -type f          \
        -name "*.json" | \
        fzf || true)

    [ -z "$prompt" ] && return 1

    mkdir -p "$session"
    echo '[]' > "$session/messages.json"
    cp "$prompt" "$session/prompt.json"

    cd "$session"
    git init -b main
    git add .
    git -c user.name="$(whoami)"            \
        -c user.email="$(whoami)@localhost" \
        commit -m "first commit"
    cd "$MOMSPACE"

    return 0
}

function session_history() {
    [ -f "$session/messages.json" ] || return 1

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
        [ "$role" != 'assistant' ] && return 1

        content=$(echo "$message" | jq -r '.content')
        reasoning_content=$(echo "$message" | jq -r '.reasoning_content')
        tool_calls=$(echo "$message" | jq -r '.tool_calls')

        style_faint_italic
        [ "$reasoning_content" != 'null' ] && \
            echo "$reasoning_content"
        style_resume
        style_bold
        [ "$content" != 'null' ] && echo "$content"
        style_resume
        [ "$tool_calls" != 'null' ] && \
            echo "$tool_calls" \
            | jq -c '.[].function | {name, arguments}'

    done

    content=

    return 0
}

function slash_session_select() {
    slash_tool_unload
    slash_tool_load

    mkdir -p session

    session=$(find session \
        -mindepth 1        \
        -maxdepth 1        \
        -type d          | \
        fzf || true)

    [ -z "$session" ] && return 1
    
    return 0
}

function slash_session_delete() {
    slash_session_select || return 1

    rm -rf "$session"

    session=

    return 0
}

function slash_session_rename() {
    slash_session_select || return 1

    while true; do

        echo
        echo -n "new session_name: "
        style_pink
        IFS= read -r session_name
        style_resume

        if [ -z "$session_name" ]; then
            style_red
            echo "session_name cannot be empty"
            style_resume

            continue
        fi

        if [ -e "session/$session_name" ]; then
            style_red
            echo "session/$session_name already existed"
            style_resume

            continue
        fi

        break

    done

    mv "$session" "session/$session_name"

    session="session/$session_name"

    return 0
}