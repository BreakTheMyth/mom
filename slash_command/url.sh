#!/bin/sh

[ -n "$URL_SH" ] && return 0
URL_SH=1

source ./style.sh

base_url=$(cat config | grep '^base_url=' | awk -F'base_url=' '{print $2}' | tr -cd '[:print:]')

function url_load() {
    list_url="$base_url/models"
    chat_url="$base_url/chat/completions"
    api_key=$(cat api_key | tr -cd '[:print:]')

    return 0
}

function slash_url_change() {
    echo -n "base_url: "

    style_pink
    IFS= read -r base_url
    style_resume

    echo -n "api_key: "
    
    IFS= read -sr api_key

    sed -i "s|^base_url=.*|base_url=$base_url|g" config
    echo "$api_key" > api_key

    url_load

    return 0
}

([ -z "$base_url" ] || [ ! -f api_key ]) && \
    slash_url_change || url_load