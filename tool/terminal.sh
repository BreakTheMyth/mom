#!/bin/sh

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
                        "minimum": 1,
                        "default": 1,
                        "description": "等待几秒后查看终端渲染结果"
                    }
                },
                "required": ["input"]
            }
        }
    }'

    return 0
}

function terminal_init() {
    rm -rf "/tmp/mom_terminal.fifo"
    mkfifo "/tmp/mom_terminal.fifo"
    setsid sht -s 80x24 -o /tmp/mom_terminal.screen --json \
        su - mom \
        < "/tmp/mom_terminal.fifo" &
    exec 3> "/tmp/mom_terminal.fifo"

    return 0
}

function terminal_exit() {
    exec 3>&-
    rm -f "/tmp/mom_terminal.*"

    return 0
}

function terminal_call() {
    input=$(echo "$1" | jq -r '.input')
    wait=$(echo "$1" | jq -r '.wait')
    [ "$wait" == 'null' ] && wait=1

    echo -n "$input" >&3
    sleep "$wait"
    echo >&3
    
    tool_retval=$(cat "/tmp/mom_terminal.screen")

    return 0
}