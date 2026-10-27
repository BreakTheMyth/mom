#!/bin/sh

WORKSPACE=$(pwd)
MOMSPACE=$(realpath $(dirname $0))

cd "$MOMSPACE"

source ./style.sh
source ./chat.sh

for sh_file in ./slash_command/*.sh; do
    source "$sh_file"
done

function cleanup() {
    style_resume

    slash_tool_unload

    [ -n "$session" ] && \
        cd "$session" && \
        git restore .

    echo -e "\e[?7h"
}

wait_for_interrupt=0

function handle_sigint() {
    [ "$wait_for_interrupt" -eq 0 ]     && \
    [ -z "$content" ] && [ -z "$line" ] && exit 0
    wait_for_interrupt=0
    content=
    line=
    word=
}

function print_stack() {
    echo
    style_red
    for ((i=$((${#FUNCNAME[@]} - 1)); i > 0; i--)); do
        for ((j=0; j < ${#FUNCNAME[@]} - i; j++)); do
            echo -n '  '
        done
        printf ' - [%s](%s:%s)\n' \
            "${FUNCNAME[$i]}" \
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

echo -ne "\e[?7l"

PS="$(basename $WORKSPACE)> "

while true; do

    if [ -z "$session" ]; then
        slash_session_select || true

        content=
        line=
        word=
    fi

    if [ -z "$session" ]; then
        slash_session_create || break
    fi

    echo -ne "\r\e[K"
    [ -z "$content" ] && echo -ne "$PS"

    style_pink
    echo -n "$line"
    style_resume

    read -srN 1 word || true

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

        [ -z "$content" ] && content="$line" \
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