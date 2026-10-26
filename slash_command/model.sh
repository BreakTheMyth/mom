#!/bin/sh

[ -n "$MODEL_SH" ] && return 0
MODEL_SH=1

source ./slash_command/url.sh

model=$(cat config | grep '^model=' | awk -F'model=' '{print $2}' | tr -cd '[:print:]')

function slash_model_change() {
    model=$(curl -X GET -sL $list_url \
        -H "Authorization: Bearer $api_key" \
        | jq -r .data[].id | fzf || true)

    [ -z "$model" ] && return 0

    sed -i "s/^model=.*/model=$model/g" config

    return 0
}

[ -z "$model" ] && slash_model_change