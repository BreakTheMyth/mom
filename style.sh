#!/bin/sh

[ -n "$STYLE_SH" ] && return
STYLE_SH=1

STYLE_ENABLE=true

alias style_red='         $STYLE_ENABLE && echo -ne "\e[31m"'
alias style_yellow='      $STYLE_ENABLE && echo -ne "\e[33m"'
alias style_blue='        $STYLE_ENABLE && echo -ne "\e[34m"'
alias style_pink='        $STYLE_ENABLE && echo -ne "\e[35;1m"'
alias style_bold='        $STYLE_ENABLE && echo -ne "\e[1m"'
alias style_faint_italic='$STYLE_ENABLE && echo -ne "\e[2m\e[3m"'
alias style_resume='      $STYLE_ENABLE && echo -ne "\e[0m"'