#!/bin/sh

[ -n "$TOOL_TERMINAL_SH" ] && return
TOOL_TERMINAL_SH=1

function terminal_desc() {
    echo '{
        "type": "function",
        "function": {
            "name": "terminal",
            "description": "模拟尺寸为 80x24 的终端, 通过字符串模拟键盘输入, 渲染完成后去除行尾空格后通过字符串返回",
            "parameters": {
                "type": "object",
                "properties": {
                    "input": {
                        "type": "string",
                        "description": "模拟键盘输入, 如果为空则只查看输出"
                    },
                    "wait": {
                        "type": "integer",
                        "description": "等待几秒后查看终端渲染结果"
                    }
                }
            }
        }
    }'
}

function terminal_init() {
    mkdir -p /tmp/session
    mkfifo "/tmp/$session.fifo"
    sht -s 80x24 -o /tmp/$session.txt --json \
        su - mom \
        < "/tmp/$session.fifo" &
    exec 3> "/tmp/$session.fifo"
}

function terminal_exit() {
    exec 3>&-
    rm -f "/tmp/$session.fifo"
}

function terminal_call() {
    input=$(echo "$1" | jq -r '.input')
    wait=$(echo "$1" | jq -r '.wait')

    echo -n "$input" >&3
    sleep "$wait"
    echo >&3
    
    tool_retval=$(cat "/tmp/$session.txt")
}