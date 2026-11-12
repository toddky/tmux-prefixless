### Layout
```
.
├── prefixless.tmux          # entry point; sets @prefixless-dir and PREFIXLESS_DIR, then sources prefixless.conf
├── prefixless.conf          # every key binding, in the prefixless key table
├── tests/run_tests.sh       # checks the config, bound scripts, script syntax and yank
├── README.md                # its key list is stale; prefixless.conf is the source of truth
└── scripts/
    ├── run                  # runs scripts/<name> with scripts/ on PATH
    ├── copy-pipe            # copies stdin to a tmux buffer and the system clipboard
    ├── kill-pane            # M-w; refuses to kill panes running certain processes
    ├── new-window           # M-n
    ├── new-window-menu      # M-N
    ├── toggle-status        # M-F
    ├── notify-choose        # M-u; notification chooser
    ├── chat-choose          # M-U; agent chat chooser
    ├── smooth-scroll        # copy mode K, J, C-u, C-d
    └── scratchpad/
        ├── popup            # borderless popup laid exactly over the pane; zoomed split on tmux older than 3.3
        ├── capture          # M-o; pane history as `$ command` blocks
        ├── yank             # M-y; symlink to yank.rb
        ├── yank.rb          # hint mode: c commands, f files and paths, g git hashes
        └── yank.py, yank.pl # older versions; nothing runs them
```

### Rules
1. This repo is public on GitHub. Never add hostnames, internal paths, or anything that names private scripts' locations.
2. M-y runs `scratchpad/yank`, which links to `yank.rb`; change yank.rb. `yank.py` and `yank.pl` are kept on purpose: never edit or delete them unless asked.
3. Bind scripts as `run-shell '#{q:@prefixless-dir}/scripts/run <name>'`. Popup and scratch pane commands can't expand formats, so inside them use `"$PREFIXLESS_DIR/scripts/run"`.
4. Scripts call each other by name, never by path; `scripts/run` puts `scripts/` on PATH. The exception is a command handed back to tmux, such as a display-menu or run-shell string: the server runs it without that PATH, so it needs the full path, as new-window-menu builds it.
5. Home and project directories may be on NFS, where forking a script takes 100+ ms. Never bind a script to a key pressed in quick succession, such as pane movement; bind tmux commands directly.
6. Anything a popup does to the filesystem, such as a stat or a git call, must run under a timeout, so a hung mount can't freeze the popup. Follow `check_missing` in yank.rb, which also skips the check when the pane runs ssh or mosh.
7. Some bindings run commands that live outside this repo, on PATH, such as `tmux-switch` (M-A) and `tmux-m-space` (M-Space). Don't look for them or add them here.
8. Gate a command that needs a newer tmux with `%if "#{>=:#{version},X.Y}"`, as M-Space does, so older tmux still loads the rest of the file.

### Verify
- Run `tests/run_tests.sh`. It loads prefixless.conf in a throwaway server, checks every bound script exists, checks every script's syntax, and runs yank against known text. It must exit 0.
- Never test against the running server, and never use `source-file -n` as a check; it exits 0 even on unknown commands and options.
- The tests can't cover the popup, since display-popup needs an attached client. After changing `popup`, press M-y and M-o in a real session.
- Reload with `M-F5` only after `tests/run_tests.sh` passes.
