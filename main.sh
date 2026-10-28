#!/bin/sh

FZF_DEFAULT_OPTS='--height ~40% --layout=reverse --prompt=" /"'

WORKSPACE=$(pwd)
MOMSPACE=$(realpath $(dirname $0))

cd "$MOMSPACE"

source ./style.sh
source ./chat.sh

for sh_file in ./slash_command/*.sh; do
    source "$sh_file"
done

function cleanup() {
    echo
    style_resume

    slash_tool_unload

    [ -n "$session" ] && \
        cd "$session" && \
        git restore .

    echo -ne "\e[?7h"
}

wait_for_interrupt=false

function handle_sigint() {
    ! $wait_for_interrupt && [ -z "$content" ] && [ -z "$line" ] && \
        exit 0

    wait_for_interrupt=false
    content=
    line=
    word=
}

function print_stack() {
    echo
    style_red
    for ((i=$((${#FUNCNAME[@]} - 1)); i > 0; i--)); do
        for ((j=0; j < ${#FUNCNAME[@]} - i; j++)); do
            echo -n '  ' >&2
        done
        printf ' - [%s](%s:%s)\n' \
            "${FUNCNAME[$i]}" \
            "${BASH_SOURCE[$i]}" \
            "${BASH_LINENO[$((i - 1))]}" >&2
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
        slash_session_select || \
        slash_session_create || \
        break
    fi

    if [ "$prev_session" != "$session" ]; then
        prev_session="$session"
        content=
        line=
        word=

        slash_tool_unload
        slash_tool_load
        session_history
    fi

    echo -ne "\r\e[K"
    [ -z "$content" ] && echo -ne "$PS"

    style_pink
    echo -n "$line"
    style_resume

    read -srN 1 word || true

    [ "$word" == '/' ] && handle_slash

    [ -z "$word" ] && continue

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

    if [ "$word" == '^H' ] || [ "$word" == '^?' ]; then
        line=${line%?}
        continue
    fi

    if [ "$word" == '^L' ]; then
        clear
        continue
    fi

    if [ "$word" == '^U' ]; then
        session_history | less -R +G
        continue
    fi

    line="$line$word"
done