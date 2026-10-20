#!/bin/sh

[ -n "$MODEL_SH" ] && return
MODEL_SH=1

source ./url.sh

model=$(cat config | grep '^model=' | awk -F'model=' '{print $2}' | tr -cd '[:print:]')

function model_change() {
    model=$(curl -X GET -sL $list_url \
        -H "Authorization: Bearer $api_key" \
        | jq -r .data[].id | fzf)

    [ -z "$model" ] && return

    sed -i "s/^model=.*/model=$model/g" config
}

[ -z "$model" ] && model_change