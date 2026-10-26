#!/bin/sh

WORKSPACE=$(pwd)
MOMSPACE=$(dirname $0)

cd "$MOMSPACE"

source ./style.sh
source ./chat.sh

for sh_file in ./slash_command/*.sh; do
    source "$sh_file"
done

function cleanup() {
    echo -e "\e[?7h"
    style_resume

    slash_tool_unload

    [ -n "$session" ] && \
        cd "$session" && \
        git restore .
}

function handle_sigint() {
    [ -z "$content" ] && [ -z "$line" ] && exit
    content=
    line=
    word=
    echo -ne "^C\n$PS"
}

function print_stack() {
    echo
    style_red
    for ((i=${#FUNCNAME[@]}; i > 0; i--)); do
        for ((j=0; j < ${#FUNCNAME[@]} - i; j++)); do
            echo -n '  '
        done
        printf ' - [%s](%s:%s)\n' \
            "${FUNCNAME[$((i - 1))]}" \
            "${BASH_SOURCE[$i]}" \
            "${BASH_LINENO[$((i - 1))]}"
    done
    style_resume
}

set -E
trap 'print_stack'   ERR
trap 'handle_sigint' INT
trap 'cleanup'       EXIT

function handle_slash() {
    cmd=$(declare -F        | \
        awk  '{print $3}'   | \
        grep '^slash_*'     | \
        sed  's/^slash_//g' | \
        tr   '_' '/'        | \
        fzf || true)

    [ -z "$cmd" ] && return 0

    echo
    "$(echo "slash_$cmd" | tr '/' '_')"

    echo -ne "\r\e[K"
    [ -z "$content" ] && echo -ne "$PS"
    style_pink
    echo -n "$line"
    style_resume
    word=

    return 0
}

slash_session_select

echo -ne "\e[?7l"

content=
line=
PS="$(whoami): "

while true; do

    echo -ne "\r\e[K"
    [ -z "$content" ] && echo -ne "$PS"

    style_pink
    echo -n "$line"
    style_resume

    read -srN 1 word

    [ "$word" == '/' ] && handle_slash

    [ -z "$word" ] && continue

    [ "$word" == $'\x7f' ] || [ "$word" == $'\x08' ] && \
        line=${line%?} && \
        continue

    if [ "$word" == $'\n' ]; then
        if [ "${line: -1}" == '\' ]; then
            content="$content"$'\n'"${line%\\}"

            line=

            style_faint_italic
            echo -e "\b\\"
            style_resume

            continue
        fi

        [ -z $content ] && content="$line" \
            || content="$content"$'\n'"$line"

        echo
        chat_send_messages "$content"

        content=
        line=

        continue
    fi

    ascii=$(printf "%d" "'$word")
    [ $ascii -eq 127 ] && word='^?'
    [ $ascii -lt 32  ] && \
        word=$(echo -ne '^'$"\x$(printf '%x' $((ascii + 64)))")

    [[ ! $word =~ [[:print:]] ]] && continue

    line="$line$word"
done