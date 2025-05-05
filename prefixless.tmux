#!/usr/bin/env bash
TMUX_PREFIXLESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="$TMUX_PREFIXLESS_ROOT/bin"
#set -ex

keytable=prefixless

function _bind() {
	local key="$1" && shift
	local cmd=("$@")

	print-cmd "${cmd[@]}"
	tmux bind-key -T "$keytable" "$key" "${cmd[@]}"
}


# ==============================================================================
# CLIENT
# ==============================================================================
_bind M-Q detach-client


# ==============================================================================
# NAVIGATION
# ==============================================================================

# Choose a session
_bind M-a choose-session -O name
_bind M-A run-shell 'tmux-switch pane'

# Switch to next/previous session with <M-S-j/k>
_bind M-J switch-client -n
_bind M-K switch-client -p

# Switch to last session
_bind M-_ switch-client -l

# Switch Session <M-S-Number>
_bind 'M-!' run-shell "$bin/switch-session.bash next 1"
_bind 'M-@' run-shell "$bin/switch-session.bash next 2"
_bind 'M-#' run-shell "$bin/switch-session.bash next 3"
_bind 'M-$' run-shell "$bin/switch-session.bash next 4"
_bind 'M-%' run-shell "$bin/switch-session.bash next 5"
_bind 'M-^' run-shell "$bin/switch-session.bash next 6"
_bind 'M-&' run-shell "$bin/switch-session.bash next 7"
_bind 'M-*' run-shell "$bin/switch-session.bash next 8"
_bind 'M-(' run-shell "$bin/switch-session.bash next 9"
_bind 'M-)' run-shell "$bin/switch-session.bash next 0"

# Switch to next/previous window with <M-S-h/l>
_bind 'M-<' previous-window
_bind 'M->' next-window
_bind 'M-H' previous-window
_bind 'M-L' next-window

# Switch to last window
_bind 'M--' select-window -l

# Select Windows <M-#>
_bind M-1 select-window -t  1
_bind M-2 select-window -t  2
_bind M-3 select-window -t  3
_bind M-4 select-window -t  4
_bind M-5 select-window -t  5
_bind M-6 select-window -t  6
_bind M-7 select-window -t  7
_bind M-8 select-window -t  8
_bind M-9 select-window -t  9
_bind M-0 select-window -t 10

# Switch panes with <M-h/j/k/l>
_bind M-k 'resize-pane -y 1 ; select-pane -U ; resize-pane -y 999'
_bind M-j 'resize-pane -y 1 ; select-pane -D ; resize-pane -y 999'
_bind M-h select-pane -L
_bind M-l select-pane -R

# Toggle zoom <M-f>
_bind M-f resize-pane -Z

# Toggle status <M-F>
_bind M-F run-shell "$bin/toggle-status.bash"


# ==============================================================================
# SESSION
# ==============================================================================

# Rename session with <M-R>
_bind M-R command-prompt 'rename-session %%'

# I no longer kill windows, instead I kill each pane individually
# Close window <M-Shift-W>
#_bind" M-W confirm-before -p "kill-window #W? (y/n)" kill-window
#_bind" M-W kill-window

# New pane with <M-S/s/V/v>
_bind M-S "split-window -vf -c '#{pane_current_path}' ; resize-pane -y 999"
_bind M-s "split-window -v  -c '#{pane_current_path}' ; resize-pane -y 999"
_bind M-V "split-window -hf -c '#{pane_current_path}'"
_bind M-v "split-window -h  -c '#{pane_current_path}'"

# Resize pane with <M-Arrow>
_bind M-Left  resize-pane -L
_bind M-Right resize-pane -R
_bind M-Up    resize-pane -U
_bind M-Down  resize-pane -D

# Swap pane with pane above/below with <M-PageUp/PageDown>
_bind 'M-PPage' 'swap-pane -U ; resize-pane -y 999'
_bind 'M-NPage' 'swap-pane -D ; resize-pane -y 999'

# Kill pane using kill-pane.bash
# kill-pane.bash prevents killing panes if certain processes are running
_bind M-w "run-shell $bin/kill-pane.bash ; resize-pane -y 999"

# Force kill pane
_bind M-W "kill-pane ; resize-pane -y 999"


# ==============================================================================
# WINDOWS
# ==============================================================================

# New/rename/swap window with <M-N/r/S-Left/S-Right>
_bind M-N         "run-shell -b $bin/new-window-menu.bash"
_bind M-n         "run-shell -b $bin/new-window.bash"
_bind 'S-M-Left'  'swap-window -t -1 ; select-window -t -1'
_bind 'S-M-Right' 'swap-window -t +1 ; select-window -t +1'
_bind M-r         "command-prompt 'rename-window %%'"

# Synchronize panes on/off with with <M-Z/z>
_bind M-Z set-window-option synchronize-panes on
_bind M-z set-window-option synchronize-panes off

# Make layout even with <M-=>
_bind M-= select-layout -E


# ==============================================================================
# PANES
# ==============================================================================

# Copy pane directory <M-d>
_bind M-d "run-shell -b $bin/copy-pane-path.bash"

# TODO: Unhardcode scratch path
# Enter "vim-mode" <M-F>
#_bind M-F run-shell -b "$HOME/.tmux/plugins/tmux-scratchpad/scripts/scratch_pane.bash '~/.tmux/bin/vim-pane.bash #{pane_id}'"

# Mark pane <M-m>
_bind M-m select-pane -m

# Toggle input <M-x>
_bind M-x "run-shell -b $bin/toggle-input.bash"

# ==============================================================================
# COPY-MODE-VI
# ==============================================================================
tmux set-window-option -g mode-keys vi

# Use tmux-picker plugin
plugin_dir="$HOME/.tmux/plugins"
tmux_picker="$plugin_dir/tmux-picker/tmux-picker.sh"
if [[ -x "$tmux_picker" ]]; then
	_bind M-y run-shell "$tmux_picker"
fi

# Enter copy mode
_bind M-Y copy-mode

# Select from paste-buffer
_bind M-P choose-buffer "paste-buffer -b %%"

# Copy Selection to System Clipboard <y>
tmux bind-key -T copy-mode-vi y send-keys -X copy-pipe "$bin/copy-pipe.bash"

# Select <v>
tmux bind-key -T copy-mode-vi v send-keys -X begin-selection

# Select using rectangle mode <C-v>
tmux bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle

# Page up/down <K/J>
tmux \
	bind-key -T copy-mode-vi K   "run-shell -b '$bin/smooth-scroll.bash   up    5'" \; \
	bind-key -T copy-mode-vi J   "run-shell -b '$bin/smooth-scroll.bash down    5'" \; \
	bind-key -T copy-mode-vi C-u "run-shell -b '$bin/smooth-scroll.bash   up half'" \; \
	bind-key -T copy-mode-vi C-d "run-shell -b '$bin/smooth-scroll.bash down half'"

# End of Line <L>
tmux bind-key -T copy-mode-vi L send-keys -X end-of-line

# Start of Line <H>
tmux bind-key -T copy-mode-vi H send-keys -X start-of-line


# ==============================================================================
# MISC
# ==============================================================================

# Reload .tmux.conf
_bind M-F5 source-file ~/.tmux.conf

_bind M-: command-prompt

# TODO: Choose new key-bindings, these are replaced with switch-session
# Choose colorscheme <M-S-1/2/3/4/5/6>
#bind-key -T "$keytable" 'M-!' run-shell '~/.tmux/bin/colorscheme.zsh red'
#bind-key -T "$keytable" 'M-@' run-shell '~/.tmux/bin/colorscheme.zsh yellow'
#bind-key -T "$keytable" 'M-#' run-shell '~/.tmux/bin/colorscheme.zsh green'
#bind-key -T "$keytable" 'M-$' run-shell '~/.tmux/bin/colorscheme.zsh blue'
#bind-key -T "$keytable" 'M-%' run-shell '~/.tmux/bin/colorscheme.zsh purple'
#bind-key -T "$keytable" 'M-^' run-shell '~/.tmux/bin/colorscheme.zsh black'


# ==============================================================================
# SET KEY-TABLE
# ==============================================================================
tmux set-option -gs key-table "$keytable"

# Enable/disable prefixless
tmux bind-key -T "root" M-o "set-option -gs key-table $keytable"
_bind M-i "set-option -gs key-table root"

