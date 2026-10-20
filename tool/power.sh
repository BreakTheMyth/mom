#!/bin/sh

[ -n "$TOOL_POWER_SH" ] && return
TOOL_POWER_SH=1

function power_desc() {
    echo '{
        "type": "function",
        "function": {
            "name": "power",
            "description": "申请 root 执行",
            "parameters": {
                "type": "object",
                "properties": {
                    "scripts": {
                        "type": "string",
                        "description": "申请 root 执行的脚本内容, 脚本执行完成后返回执行日志, 可能遇到: 1. 执行前被用户拒绝; 2. 执行时用户忘记密码; 3. 执行时因脚本内容导致永久阻塞无法返回;"
                    }
                }
            }
        }
    }'
}

function power_init() {
    return
}

function power_exit() {
    return
}

function power_call() {
    scripts=$(echo "$1" | jq -r '.scripts')

    sh_file="/tmp/$session.sh"

    mark="# Deleting this line means you agree"
    echo "$scripts" > "$sh_file"
    echo           >> "$sh_file"
    echo "$mark"   >> "$sh_file"

    vim "$sh_file"

    if [ -n "$(grep "^$mark" "$sh_file")" ]; then
        tool_retval="Refused"
        return
    fi

    sudo chmod +x "$sh_file"
    tool_retval="$(sudo "$sh_file" 2>&1)"
    sudo -k
}