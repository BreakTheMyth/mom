#!/bin/sh

[ -n "$VIM_SH" ] && return 0
VIM_SH=1

source ./style.sh

function slash_vim() {
    tempfile=$(mktemp)

    STYLE_ENABLE=false session_history \
    | sed 's/^/# /g' > "$tempfile"
    echo "$content" >> "$tempfile"
    echo "$line"    >> "$tempfile"

    vim + "$tempfile"
    new_content=$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$tempfile")

    [ -z "$new_content" ] && return 0

    echo
    echo -ne "$PS"
    style_pink
    echo "$new_content"
    style_resume

    chat_send_messages "$new_content"

    rm -f "$tempfile"
    content=
    line=

    return 0
}