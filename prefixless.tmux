#!/usr/bin/env bash
# USAGE: prefixless.tmux
# DESCRIPTION: Load the prefixless key bindings; tmux runs this via run-shell or TPM.

# prefixless.conf finds its scripts through @prefixless-dir, so set it before sourcing.
plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux set-option -g @prefixless-dir "$plugin_dir"
if ! tmux source-file "$plugin_dir/prefixless.conf"; then
	tmux display-message "ERROR: prefixless: cannot load $plugin_dir/prefixless.conf"
	exit 1
fi
