#!/bin/sh

[ -n "$CLEAR_SH" ] && return 0
CLEAR_SH=1

function slash_clear() {
    echo '[]' > "$session/messages.json"

    cd "$session"
    git add .
    git -c user.name="$(whoami)"            \
        -c user.email="$(whoami)@localhost" \
        commit -m "first commit" > /dev/null
    cd "$MOMSPACE"

    clear

    return 0
}