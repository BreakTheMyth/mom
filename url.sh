#!/bin/sh

[ -n "$URL_SH" ] && return
URL_SH=1

source ./style.sh

base_url=$(cat config | grep '^base_url=' | awk -F'base_url=' '{print $2}' | tr -cd '[:print:]')

function url_load() {
    list_url="$base_url/models"
    chat_url="$base_url/chat/completions"
    api_key=$(cat api_key | tr -cd '[:print:]')
}

function url_change() {
    echo -n "base_url: "

    style_pink
    read base_url
    style_resume

    echo -n "api_key: "
    
    read -s api_key

    sed -i "s|^base_url=.*|base_url=$base_url|g" config
    echo "$api_key" > api_key

    url_load
}

[ -z "$base_url" ] && url_change || url_load