#!/bin/sh

[ -n "$QUIT_SH" ] && return 0
QUIT_SH=1

function slash_quit() {
    exit 0
}