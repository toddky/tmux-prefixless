
tmux-prefixless
================================================================================

Description
--------------------------------------------------------------------------------

I hate using a prefix key with `tmux`.

Instead, I use `<alt-key>`. This feels intuitive because I hold down `<alt>` with
my thumb, to navigate to the session with `J`/`K`, then window with `H`/`L`, then
pane with `h`/`j`/`k`/`l`. Then I release `<alt>`. This enables me to effiently
navigate tmux without using a prefix. I also don't like `tmux`'s `repeat-time`
option because relying on timing to enter commands is error-prone.

But what happens when I need to use the `<alt>` key for `emacs` or nested `tmux`
sessions? First of all, I use `vim` instead of `emacs`. Secondly, I can disable
my keybindings with `<alt-i>` and re-enable them with `<alt-o>`.

[//]: # (TODO: Write a better description.)
[//]: # (TODO: Add gif.)


Installation
--------------------------------------------------------------------------------

### Via TPM (recommended)

``` tmux
set -g @plugin 'toddky/tmux-prefixless'
```

[//]: # (TODO: Add mannual installation.)


Usage
--------------------------------------------------------------------------------
For a list of keyboard shortcuts, simply run:

```sh
tmux list-keys -T prefixless
```

Slightly modifiedresult below:
```sh
M-!       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 1"
M-@       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 2"
"M-#"     run-shell "$PLUGIN_PATH/bin/switch-session.bash next 3"
"M-$"     run-shell "$PLUGIN_PATH/bin/switch-session.bash next 4"
M-%       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 5"
M-^       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 6"
M-&       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 7"
M-*       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 8"
M-(       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 9"
M-)       run-shell "$PLUGIN_PATH/bin/switch-session.bash next 0"

M--       select-window -l
M-1       select-window -t 1
M-2       select-window -t 2
M-3       select-window -t 3
M-4       select-window -t 4
M-5       select-window -t 5
M-6       select-window -t 6
M-7       select-window -t 7
M-8       select-window -t 8
M-9       select-window -t 9
M-0       select-window -t 10

M-_       switch-client -l
M-:       command-prompt

M-<       previous-window
M->       next-window
M-=       select-layout -E

M-A       run-shell "tmux-switch pane"
M-F       run-shell -b "$PLUGIN_PATH/bash '~/.tmux/bin/vim-pane.bash #{pane_id}'"
M-H       previous-window
M-J       switch-client -n
M-K       switch-client -p
M-L       next-window
M-N       run-shell -b $PLUGIN_PATH/bin/new-window-menu.bash
M-P       choose-buffer "paste-buffer -b %%"
M-Q       detach-client
M-R       command-prompt "rename-session %%"
M-S       split-window -fv -c "#{pane_current_path}" \; resize-pane -y 999
M-V       split-window -fh -c "#{pane_current_path}"
M-Y       copy-mode
M-Z       set-window-option synchronize-panes on

M-a       choose-tree -s -O name
M-d       run-shell -b $PLUGIN_PATH/bin/copy-pane-path.bash
M-f       resize-pane -Z
M-h       select-pane -L
M-i       set-option -gs key-table root
M-j       resize-pane -y 1 \; select-pane -D \; resize-pane -y 999
M-k       resize-pane -y 1 \; select-pane -U \; resize-pane -y 999
M-l       select-pane -R
M-m       select-pane -m
M-n       run-shell -b $PLUGIN_PATH/bin/new-window.bash
M-r       command-prompt "rename-window %%"
M-s       split-window -v -c "#{pane_current_path}" \; resize-pane -y 999
M-v       split-window -h -c "#{pane_current_path}"
M-w       run-shell $PLUGIN_PATH/bin/kill-pane.bash \; resize-pane -y 999
M-y       run-shell $TMUX_PLUGINS/tmux-picker/tmux-picker.sh
M-z       set-window-option synchronize-panes off

M-F5      source-file $HOME/.tmux.conf
M-NPage   swap-pane -D \; resize-pane -y 999
M-PPage   swap-pane -U \; resize-pane -y 999
M-Up      resize-pane -U
M-Down    resize-pane -D
M-Left    resize-pane -L
M-Right   resize-pane -R
M-S-Left  swap-window -t -1 \; select-window -t -1
M-S-Right swap-window -t +1 \; select-window -t +1
```

About
--------------------------------------------------------------------------------

### Author
[toddyamakawa](https://github.com/toddyamakawa)

### License
[MIT](LICENSE.md)

