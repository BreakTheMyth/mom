#!/bin/sh

WORKSPACE=$(pwd)
MOMSPACE=$(dirname $0)

cd "$MOMSPACE"

source ./style.sh
source ./chat.sh

chat_select_session

tool_load

while true; do
    echo -n "$(whoami): "
    style_pink
    read content
    style_resume
    [ "$content" == 'exit' ] && break
    chat_send_messages "$content"
done

source ./cleanup.sh
