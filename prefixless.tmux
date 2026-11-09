#!/usr/bin/env bash
# USAGE: prefixless.tmux
# DESCRIPTION: Load the prefixless key bindings; tmux runs this via run-shell or TPM.

# prefixless.conf finds its scripts through @prefixless-dir, so set it before sourcing.
# Scratch panes and popups can't expand formats in their commands, so they read PREFIXLESS_DIR from the environment.
plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux set-option -g @prefixless-dir "$plugin_dir"
tmux set-environment -g PREFIXLESS_DIR "$plugin_dir"
if ! tmux source-file "$plugin_dir/prefixless.conf"; then
	tmux display-message "ERROR: prefixless: cannot load $plugin_dir/prefixless.conf"
	exit 1
fi
