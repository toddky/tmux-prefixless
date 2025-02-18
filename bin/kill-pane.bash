#!/usr/bin/env bash

# Check if readonly
ro="$(tmux display-message -p '#{pane_input_off}')"
if ((ro)); then
	tmux display-message "Unable to kill-pane that is readonly"
	exit
fi


cmd="$(tmux display-message -p '#{pane_current_command}')"

case "$cmd" in

	# Keep pane alive if running jobs
	nios|srun)
		tmux display-message "Unable to kill-pane running '$cmd'"
		;;

	# Confirm before killing pane
	nvim|vim|ssh)
		tmux confirm-before -p "kill-pane running '$cmd'? (y/n)" kill-pane || true
		exit 0
		;;

	# Kill pane running certain processes
	bash|fish|less|zsh|man)
		tmux kill-pane
		;;

	*)
		tmux confirm-before -p "kill-pane running '$cmd'? (y/n)" kill-pane || true
		;;
esac

