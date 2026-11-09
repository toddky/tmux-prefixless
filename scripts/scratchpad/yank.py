#!/usr/bin/env python3
# vim: ft=python noet ts=4 sw=0 sts=0
"""Redraw a pane with two-letter hints over commands and file names; typing a hint copies that text.

USAGE: yank.py [-t target-pane]
Meant to run in a popup laid exactly over the pane (scratchpad/popup), so the hints sit on the text they copy.
Keys: a two-letter hint copies, <Esc> clears a half-typed hint, q quits.
After the first key only the hints that still match stay highlighted.
"""

import argparse
import atexit
import re
import subprocess
import sys
import termios
import tty
import unicodedata


# ==============================================================================
# ARGUMENTS
# ==============================================================================
parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument('-t', '--target', help='tmux target pane (default: the current pane)')
args = parser.parse_args()


# ==============================================================================
# ENVIRONMENT
# ==============================================================================
CLEAR_SCREEN = '\033[H\033[2J'
HIDE_CURSOR = '\033[?25l'
SHOW_CURSOR = '\033[?25h'
RESET = '\033[0m'

# The whole match is highlighted in muted blue and its hint sits on its first two cells in light blue.
HIGHLIGHT_COLOR = '\033[38;5;255;48;5;24m'
HINT_COLOR = '\033[1;38;5;0;48;5;117m'

# 'q' quits, so it can't be a hint character.
HINT_CHARACTERS = 'fdsavcxzrewtgb1234567890jklmuiopyhn'

ANSI_ESCAPE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')


# ==============================================================================
# HELPERS
# ==============================================================================
def tmux(arguments):
	return subprocess.run(['tmux', *arguments], check=True, capture_output=True, text=True)


def message(text):
	tmux(['display-message', text])
	return None


def find_matches(lines, regex, group):
	'''Return [text, row, column] for each line matching regex; column is in terminal cells.'''
	matches = []
	for row, line in enumerate(lines):
		match = re.match(regex, line)
		if not match:
			continue
		before_match = line[:match.start(group)]
		# East Asian wide characters take two cells, so a plain len() would put later hints too far left.
		column = sum(2 if unicodedata.east_asian_width(character) in 'WF' else 1 for character in before_match)
		matches.append([match.group(group), row, column])
	return matches


def draw(colored_lines, hints, typed):
	'''Redraw the pane, then highlight every match whose hint starts with what has been typed so far.'''
	# Place every row and hint by absolute position; a stray newline on the last row would scroll the popup.
	screen = [HIDE_CURSOR, CLEAR_SCREEN]
	for row, colored_line in enumerate(colored_lines):
		screen.append(f'\033[{row + 1};1H{colored_line}{RESET}')
	for hint, (text, row, column) in hints.items():
		if not hint.startswith(typed):
			continue
		screen.append(f'\033[{row + 1};{column + 1}H{HIGHLIGHT_COLOR}{text}{RESET}')
		screen.append(f'\033[{row + 1};{column + 1}H{HINT_COLOR}{hint}{RESET}')
	sys.stdout.write(''.join(screen))
	sys.stdout.flush()
	return None


# ==============================================================================
# CAPTURE PANE
# ==============================================================================
capture_arguments = ['capture-pane', '-p', '-e']
if args.target:
	capture_arguments.extend(['-t', args.target])
try:
	pane_contents = tmux(capture_arguments).stdout
except subprocess.CalledProcessError as error:
	sys.exit(f'ERROR: yank: tmux capture-pane failed ({error.stderr.strip()}); check that -t names a live pane')

# One entry per pane row; keep blank rows so row numbers match the pane.
colored_lines = pane_contents.split('\n')
if colored_lines and colored_lines[-1] == '':
	colored_lines.pop()
lines = [ANSI_ESCAPE.sub('', colored_line) for colored_line in colored_lines]


# ==============================================================================
# FIND MATCHES
# ==============================================================================
all_matches = {}

# todd 755 bin main » <command>
all_matches['command'] = find_matches(lines, r".*»\s*(\S.*)", 1)

# lrwxrwxrwx 1 todd group   11 Jan  1 23:59 file -> /path/to/file
# drwxrwxrwx 1 todd group    0 Jan  1 23:59 dir/
# -rw-r--r-- 1 todd group  10K Jan  1 23:59 file.txt
all_matches['file'] = find_matches(lines, r"[-dl]([-r][-w][-x]){3}.* (\S+)", 2)


# ==============================================================================
# GENERATE HINTS
# ==============================================================================
hints = {}
for kind, matches in all_matches.items():
	# REVISIT: Support more matches than hint characters.
	for match, hint_character in zip(matches, HINT_CHARACTERS):
		hints[f'{kind[0]}{hint_character}'] = match


# ==============================================================================
# READ KEYS
# ==============================================================================
stdin_descriptor = sys.stdin.fileno()
original_settings = termios.tcgetattr(stdin_descriptor)

def restore_terminal():
	termios.tcsetattr(stdin_descriptor, termios.TCSADRAIN, original_settings)
	sys.stdout.write(SHOW_CURSOR)
	sys.stdout.flush()
	return None

atexit.register(restore_terminal)
tty.setraw(stdin_descriptor)

typed = ''
draw(colored_lines, hints, typed)
while True:
	key = sys.stdin.read(1)
	if key == 'q':
		sys.exit(0)
	if key == '\x1b':
		typed = ''
		draw(colored_lines, hints, typed)
		continue

	candidates = [hint for hint in hints if hint.startswith(typed + key)]
	if not candidates:
		continue
	typed += key
	if typed not in hints:
		draw(colored_lines, hints, typed)
		continue

	text = hints[typed][0]
	tmux(['set-buffer', text])
	# scripts/run puts scripts/ on PATH, so copy-pipe is the same script copy-mode <y> uses.
	try:
		subprocess.run(['copy-pipe'], input=text, check=True, text=True)
	except (FileNotFoundError, subprocess.CalledProcessError):
		message('WARNING: yank: copy-pipe failed; copied to a tmux buffer only')
		sys.exit(0)
	message(f'Copied: {text}')
	sys.exit(0)
