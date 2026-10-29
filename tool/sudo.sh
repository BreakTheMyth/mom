#!/bin/sh

function sudo_desc() {
    echo '{
        "type": "function",
        "function": {
            "name": "sudo",
            "description": "申请 root 执行",
            "parameters": {
                "type": "object",
                "properties": {
                    "scripts": {
                        "type": "string",
                        "description": "申请 root 执行的脚本内容, 脚本执行完成后返回执行日志, 可能遇到: 1. 执行前被用户拒绝; 2. 执行时用户忘记密码; 3. 执行时因脚本内容导致永久阻塞无法返回;"
                    }
                },
                "required": ["scripts"]
            }
        }
    }'

    return 0
}

function sudo_init() {
    return 0
}

function sudo_exit() {
    rm -rf "/tmp/$(whoami)/mom_sudo.*"
    return 0
}

function sudo_call() {
    scripts=$(echo "$1" | jq -r '.scripts')

    mkdir -p "/tmp/$(whoami)"
    sh_file="/tmp/$(whoami)/mom_sudo.sh"

    mark="# Deleting this line means you agree"
    echo "$scripts" > "$sh_file"
    echo           >> "$sh_file"
    echo "$mark"   >> "$sh_file"

    vim "$sh_file"

    if [ -n "$(grep "^$mark" "$sh_file")" ]; then
        tool_result="Refused"
        return 1
    fi

    echo "$scripts" > "$sh_file"
    sudo chmod +x "$sh_file"
    tool_result="$(sudo "$sh_file" 2>&1)"
    sudo -k
    rm -f "$sh_file"

    return 0
}