#!/bin/sh

[ -n "$STYLE_SH" ] && return
STYLE_SH=1

alias style_red='echo -ne "\e[31m"'
alias style_yellow='echo -ne "\e[33m"'
alias style_pink='echo -ne "\e[35;1m"'
alias style_bold='echo -ne "\e[1m"'
alias style_faint_italic='echo -ne "\e[2m\e[3m"'
alias style_resume='echo -ne "\e[0m"'