#!/bin/sh

WORKSPACE=$(pwd)
MOMSPACE=$(dirname $0)

cd "$MOMSPACE"

source ./style.sh
source ./chat.sh

function cleanup() {
    echo -e "\e[?7h"
    style_resume

    tool_unload

    [ -n "$session" ] && \
        cd "$session" && \
        git restore .
}

function handle_sigint() {
    [ -z "$content" ] && [ -z "$line" ] && exit
    content=""
    line=""
    word=""
    echo -ne "^C\n$PS"
}

trap 'cleanup'       EXIT
trap 'handle_sigint' INT

function handle_slash() {
    return
}

chat_select_session

echo -ne "\e[?7l"

content=""
line=""
PS="$(whoami): "

echo -ne "$PS"

while true; do

    read -srN 1 word

    [ -z "$word" ] && continue

    if [ "$word" == $'\x7f' ] || [ "$word" == $'\x08' ]; then
        line=${line%?}

        echo -ne "\r\e[K"
        [ -z "$content" ] && echo -ne "$PS"

        style_pink
        echo -n "$line"
        style_resume

        continue
    fi

    if [ "$word" == $'\n' ]; then
        if [ "${line: -1}" == '\' ]; then
            content="$content"$'\n'"${line%\\}"

            line=""

            style_faint_italic
            echo -e "\b\\"
            style_resume

            continue
        fi

        [ -z $content ] && content="$line" \
            || content="$content"$'\n'"$line"

        echo
        chat_send_messages "$content"

        echo -ne "\n$PS"

        content=""
        line=""

        continue
    fi

    ascii=$(printf "%d" "'$word")
    [ $ascii -eq 127 ] && word='^?'
    [ $ascii -lt 32  ] && \
        word=$(echo -ne '^'$"\x$(printf '%x' $((ascii + 64)))")

    [[ ! $word =~ [[:print:]] ]] && continue

    line="$line$word"

    style_pink
    echo -n "$word"
    style_resume
done