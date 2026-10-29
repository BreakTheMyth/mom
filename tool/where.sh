#!/bin/sh

function where_desc() {
    echo '{
        "type": "function",
        "function": {
            "name": "where",
            "description": "获取用户所在的目录",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    }'

    return 0
}

function where_init() {
    return 0
}

function where_exit() {
    return 0
}

function where_call() {
    tool_result="$WORKSPACE"

    return 0
}