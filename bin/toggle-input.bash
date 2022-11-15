#!/usr/bin/env bash
readonly="$(tmux display-message -p '#{pane_input_off}')"
if ((readonly)); then
	tmux select-pane -e
else
	tmux select-pane -d
fi

