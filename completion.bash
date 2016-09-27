#!/bin/bash

_swift() 
{
    local cur prev opts words
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    words=$(COMP_LINE=${COMP_LINE} COMP_POINT=${COMP_POINT} /Users/bouke/Developer/swift-package-manager/.build/debug/swift-package completions swift "${cur}" "${prev}")
    if [[ "$words" == "<path>" ]]; then
        _filedir
        # echo $words
        # COMPREPLY=$("hello")
    else
        # COMPREPLY=()
        # echo $words
        COMPREPLY=( $(compgen -W "${words}" -- "") )
    fi
}
complete -F _swift swift
