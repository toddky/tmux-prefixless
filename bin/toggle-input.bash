#!/usr/bin/env bash
ro="$(tmux display-message -p '#{pane_input_off}')"
if ((ro)); then
	tmux select-pane -e
else
	tmux select-pane -d
fi

