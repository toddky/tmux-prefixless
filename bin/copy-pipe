#!/usr/bin/env bash

# TODO: Figure out how to check if this works
if (type copy-osc52 &>/dev/null); then
	# https://medium.com/free-code-camp/tmux-in-practice-integration-with-system-clipboard-bcd72c62ff7b
	tmux set-option -g set-clipboard on
	tmux bind-key -T copy-mode-vi y send-keys -X copy-pipe copy-osc52
fi

if (type ,copy &>/dev/null); then
	,copy
elif (type xclip &>/dev/null); then
	xclip -selection clipboard
	xclip -selection primary
fi

