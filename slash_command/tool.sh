#!/bin/sh

[ -n "$TOOL_SH" ] && return 0
TOOL_SH=1

source ./style.sh

tools='[]'

function slash_tool_load() {
    for tool in ./tool/*.sh; do
        source "$tool"

        tool_name=$(basename "$tool" .sh)
        tool_desc=$("$tool_name"_desc)

        style_blue
        echo "Loading tool/$tool_name"
        style_resume

        "$tool_name"_init

        tools=$(echo "$tools" | jq \
            --argjson tool_desc "$tool_desc" \
            '. += [$tool_desc]')
    done

    return 0
}

function slash_tool_unload() {
    for tool_name in $(echo "$tools" | jq -r '.[].function.name'); do
        style_blue
        echo "Unloading tool/$tool_name"
        style_resume

        "$tool_name"_exit

        unset -f "$tool_name"_desc
        unset -f "$tool_name"_init
        unset -f "$tool_name"_exit
        unset -f "$tool_name"_call
    done

    tools='[]'

    return 0
}