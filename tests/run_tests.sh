#!/usr/bin/env bash
# USAGE: tests/run_tests.sh
# DESCRIPTION: Check prefixless.conf, its bound scripts, script syntax and yank in a throwaway tmux server.
# Prints PASS or FAIL per check and exits 1 if any check fails. Never touches the running tmux server.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# ==============================================================================
# ENVIRONMENT
# ==============================================================================
num_failures=0

# tmux can't open a socket path longer than about 100 characters, and $TMPDIR may already be that long.
if ! socket_dir="$(mktemp -d /tmp/tmux-check.XXXXXX)"; then
	echo "ERROR: run_tests.sh: cannot create a socket directory in /tmp" 1>&2
	exit 1
fi
socket_file="$socket_dir/socket"
trap 'command tmux -S "$socket_file" kill-server 2>/dev/null; rm -rf "$socket_dir"' EXIT


# ==============================================================================
# HELPERS
# ==============================================================================
function tmux() {
	command tmux -S "$socket_file" "$@"
}

function pass() {
	echo "PASS: $*"
}

function fail() {
	echo "FAIL: $*"
	num_failures=$((num_failures + 1))
}

# Poll instead of a fixed sleep; a cold ruby start on a network filesystem can take over a second.
function wait_for() {
	local timeout_tenths="$1" && shift
	local attempt
	for ((attempt = 0; attempt < timeout_tenths; attempt++)); do
		if "$@"; then
			return 0
		fi
		sleep 0.1
	done
	return 1
}


# ==============================================================================
# START SERVER
# ==============================================================================
# The first pane holds known text for the yank check: one path that exists and one that does not.
sample_text='ls is /usr/bin/ls\n/no/such/path\n'
if ! sample_pane="$(tmux -f /dev/null new-session -d -P -F '#{pane_id}' -x 100 -y 10 "printf '$sample_text'; cat")"; then
	echo "ERROR: run_tests.sh: cannot start a throwaway tmux server on $socket_file" 1>&2
	exit 1
fi


# ==============================================================================
# CHECK CONFIG
# ==============================================================================
# source-file -n exits 0 even on unknown commands, so source it for real; any output is an error.
if ! output="$(tmux source-file prefixless.conf 2>&1)" || [[ -n "$output" ]]; then
	fail "prefixless.conf: $output"
else
	pass "prefixless.conf loads"
fi


# ==============================================================================
# CHECK BOUND SCRIPTS
# ==============================================================================
# @prefixless-dir expands only at key press, so loading the config can't show a missing script.
failures_before=$num_failures
mapfile -t bound_scripts < <(grep -o -E 'scripts/run(\\?")? +[A-Za-z0-9/._-]+' prefixless.conf | awk '{print $NF}' | sort -u)
if ((${#bound_scripts[@]} == 0)); then
	fail "found no scripts/run bindings in prefixless.conf; the pattern in tests/run_tests.sh is out of date"
fi
for script_name in "${bound_scripts[@]}"; do
	if [[ ! -x "scripts/$script_name" ]]; then
		fail "prefixless.conf binds scripts/$script_name, which is missing or not executable"
	fi
done
if ((num_failures == failures_before)); then
	pass "all ${#bound_scripts[@]} bound scripts exist"
fi


# ==============================================================================
# CHECK SYNTAX
# ==============================================================================
failures_before=$num_failures
for script_file in scripts/* scripts/scratchpad/*; do
	if [[ ! -f "$script_file" || -L "$script_file" ]]; then
		continue
	fi
	case "$(head -n 1 "$script_file")" in
		*bash*) syntax_command=(bash -n);;
		*ruby*) syntax_command=(ruby -c);;
		*perl*) syntax_command=(perl -c);;
		*python*) syntax_command=(env PYTHONPYCACHEPREFIX="$socket_dir/pycache" python3 -m py_compile);;
		*) fail "$script_file: unknown interpreter; add it to tests/run_tests.sh"; continue;;
	esac
	if ! output="$("${syntax_command[@]}" "$script_file" 2>&1 1>/dev/null)"; then
		fail "$script_file: $output"
	fi
done
if ((num_failures == failures_before)); then
	pass "script syntax"
fi


# ==============================================================================
# CHECK YANK
# ==============================================================================
# The popup needs an attached client, so yank runs in a second window aimed at the sample pane instead.
function yank_ready() {
	tmux capture-pane -p -t "$yank_pane" | grep -q 'YANK'
}

function yank_copied() {
	[[ "$(tmux show-buffer 2>/dev/null)" == '/no/such/path' ]]
}

if ! yank_pane="$(tmux new-window -d -P -F '#{pane_id}' "'$REPO_DIR/scripts/run' scratchpad/yank -t $sample_pane")"; then
	fail "yank: cannot open a window for it"
elif ! wait_for 50 yank_ready; then
	fail "yank: no YANK badge after 5s; screen was:"
	tmux capture-pane -p -t "$yank_pane"
else
	# Hints go in order: ff on the path that exists, then fd in the missing-path colors (210 on 124).
	screen="$(tmux capture-pane -p -e -t "$yank_pane")"
	if ! grep -q $'48;5;117mff\e\\[0m\e\\[38;5;255m\e\\[48;5;24msr/bin/ls' <<<"$screen"; then
		fail "yank: no blue ff hint on /usr/bin/ls"
	fi
	if ! grep -q $'48;5;210mfd\e\\[0m\e\\[38;5;255m\e\\[48;5;124mo/such/path' <<<"$screen"; then
		fail "yank: no red fd hint on /no/such/path"
	fi
	tmux send-keys -t "$yank_pane" f d
	if ! wait_for 20 yank_copied; then
		fail "yank: typing fd did not copy /no/such/path; buffer is: $(tmux show-buffer 2>&1)"
	else
		pass "yank hints and copies"
	fi
fi


# ==============================================================================
# REPORT
# ==============================================================================
if ((num_failures > 0)); then
	echo "$num_failures check(s) failed"
	exit 1
fi
echo "all checks passed"
