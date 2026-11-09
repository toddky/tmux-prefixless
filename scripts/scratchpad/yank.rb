#!/usr/bin/env ruby
# vi: ft=ruby noet ts=4 sw=0 sts=0
# USAGE: yank [-t target-pane]
# DESCRIPTION: Redraw a pane with two-letter hints over commands and file names; typing a hint copies that text.
# Meant to run in a popup laid exactly over the pane (scratchpad/popup), so the hints sit on the text they copy.
# Keys: a two-letter hint copies, <Esc> clears a half-typed hint, q quits.
# After the first key only the hints that still match stay highlighted.

require 'io/console'
require 'open3'
require 'optparse'

# ==============================================================================
# ARGUMENTS
# ==============================================================================
options = {}
parser = OptionParser.new
parser.banner = 'usage: yank [-t target-pane]'
parser.on('-t', '--target PANE', 'tmux target pane (default: the current pane)')
parser.parse!(into: options)


# ==============================================================================
# ENVIRONMENT
# ==============================================================================
CLEAR_SCREEN = "\e[H\e[2J"
HIDE_CURSOR = "\e[?25l"
SHOW_CURSOR = "\e[?25h"
RESET = "\e[0m"

# The whole match is highlighted in muted blue and its hint sits on its first two cells in light blue.
HIGHLIGHT_COLOR = "\e[38;5;255;48;5;24m"
HINT_COLOR = "\e[1;38;5;0;48;5;117m"

# 'q' quits, so it can't be a hint character.
HINT_CHARACTERS = 'fdsavcxzrewtgb1234567890jklmuiopyhn'

ANSI_ESCAPE = /\e(?:[@-Z\\-_]|\[[0-?]*[ -\/]*[@-~])/

# Ruby's stdlib has no East Asian Width table, so this covers the common wide scripts.
# CJK, kana, Hangul, CJK punctuation, fullwidth forms, and the main emoji blocks take two cells.
WIDE_CHARACTER = /[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}　-〿！-｠￠-￦\u{1F300}-\u{1FAFF}]/


# ==============================================================================
# HELPERS
# ==============================================================================
def tmux(arguments)
	return Open3.capture3('tmux', *arguments)
end

def message(text)
	tmux(['display-message', text])
	return nil
end

# Terminal columns taken by text; wide characters take two.
def display_width(text)
	num_wide = text.scan(WIDE_CHARACTER).length
	return text.length + num_wide
end

# Copy to the system clipboard through copy-pipe, and keep a tmux buffer for M-P.
def copy(text)
	tmux(['set-buffer', text])
	# scripts/run puts scripts/ on PATH, so copy-pipe is the same script copy-mode <y> uses.
	begin
		Open3.capture3('copy-pipe', stdin_data: text)
	rescue Errno::ENOENT
		message('WARNING: yank: copy-pipe not found; copied to a tmux buffer only')
	end
	return nil
end

# Return { text, row, column } for each line matching regex; column is in terminal cells.
def find_matches(lines, regex, group)
	matches = []
	lines.each_with_index do |line, row|
		match = line.match(regex)
		next unless match
		before_match = line[0...match.begin(group)]
		matches.append({ text: match[group], row: row, column: display_width(before_match) })
	end
	return matches
end

# Redraw the pane, then highlight every match whose hint starts with what has been typed so far.
def draw(colored_lines, hints, typed)
	# Place every row and hint by absolute position; a stray newline on the last row would scroll the popup.
	screen = []
	screen.append(HIDE_CURSOR, CLEAR_SCREEN)
	colored_lines.each_with_index do |colored_line, row|
		screen.append("\e[#{row + 1};1H#{colored_line}#{RESET}")
	end
	hints.each do |hint, match|
		next unless hint.start_with?(typed)
		position = "\e[#{match[:row] + 1};#{match[:column] + 1}H"
		screen.append("#{position}#{HIGHLIGHT_COLOR}#{match[:text]}#{RESET}")
		screen.append("#{position}#{HINT_COLOR}#{hint}#{RESET}")
	end
	$stdout.write(screen.join)
	$stdout.flush
	return nil
end


# ==============================================================================
# CAPTURE PANE
# ==============================================================================
capture_arguments = []
capture_arguments.append('capture-pane', '-p', '-e')
capture_arguments.append('-t', options[:target]) if options[:target]
pane_contents, error_output, status = tmux(capture_arguments)
abort "ERROR: yank: tmux capture-pane failed (#{error_output.strip}); check that -t names a live pane" unless status.success?

# One entry per pane row; keep blank rows so row numbers match the pane.
colored_lines = pane_contents.force_encoding('UTF-8').split("\n", -1)
colored_lines.pop if colored_lines.last == ''
lines = colored_lines.map { |colored_line| colored_line.gsub(ANSI_ESCAPE, '') }


# ==============================================================================
# FIND MATCHES
# ==============================================================================
all_matches = {}

# todd 755 bin main » <command>
all_matches['command'] = find_matches(lines, /\A.*»\s*(\S.*)/, 1)

# lrwxrwxrwx 1 todd group   11 Jan  1 23:59 file -> /path/to/file
# drwxrwxrwx 1 todd group    0 Jan  1 23:59 dir/
# -rw-r--r-- 1 todd group  10K Jan  1 23:59 file.txt
all_matches['file'] = find_matches(lines, /\A[-dl]([-r][-w][-x]){3}.* (\S+)/, 2)


# ==============================================================================
# GENERATE HINTS
# ==============================================================================
hints = {}
hint_characters = HINT_CHARACTERS.chars
all_matches.each do |kind, matches|
	# REVISIT: Support more matches than hint characters.
	hinted_matches = matches.first(hint_characters.length)
	hinted_matches.each_with_index do |match, index|
		hints["#{kind[0]}#{hint_characters[index]}"] = match
	end
end


# ==============================================================================
# READ KEYS
# ==============================================================================
at_exit do
	$stdout.write(SHOW_CURSOR)
	$stdout.flush
end

# raw restores the terminal mode when the block exits, including on an exception.
typed = ''
$stdin.raw do |input|
	draw(colored_lines, hints, typed)
	loop do
		key = input.getc
		break if key.nil? || key == 'q'
		if key == "\e"
			typed = ''
			draw(colored_lines, hints, typed)
			next
		end

		candidates = hints.keys.select { |hint| hint.start_with?(typed + key) }
		next if candidates.empty?
		typed += key
		if hints.key?(typed)
			text = hints[typed][:text]
			copy(text)
			message("Copied: #{text}")
			break
		end
		draw(colored_lines, hints, typed)
	end
end
