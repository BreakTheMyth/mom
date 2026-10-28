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
    vim_content=$(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$tempfile")

    [ -z "$vim_content" ] && return 0

    echo
    echo -ne "$PS"
    style_pink
    echo "$vim_content"
    style_resume

    chat_send_messages "$vim_content"

    rm -f "$tempfile"
    content=
    line=

    return 0
}