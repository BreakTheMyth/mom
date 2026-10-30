#!/bin/sh

[ -n "$VIM_SH" ] && return 0
VIM_SH=1

source ./style.sh

function slash_vim() {
    tempfile=$(mktemp)

    STYLE_ENABLE=false session_history | \
        sed 's/^/\/\/ /g' > "$tempfile"

    echo "$content" >> "$tempfile"
    echo "$line"    >> "$tempfile"

    vim + "$tempfile"
    vim_content=$(sed '/^[[:space:]]*\/\//d; /^[[:space:]]*$/d' "$tempfile")
    rm -f "$tempfile"

    content="$vim_content"
    line=

    echo
    echo -ne "$PS"
    style_pink
    echo "$content"
    style_resume

    return 0
}