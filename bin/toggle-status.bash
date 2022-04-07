#!/usr/bin/env bash

# Get status
status="$(tmux show-option -g status)"

# If status is on, turn it off
if [[ "$status" == 'status on' ]]; then
	tmux set-option -g status off
	tmux set-option -g status off
	tmux set-window-option -g pane-border-status off

# If status is off, turn it on
else
	tmux set-option -g status on
	tmux set-window-option -g pane-border-status bottom
fi

