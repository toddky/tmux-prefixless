#!/usr/bin/env ruby
# vi: ft=ruby noet ts=4 sw=0 sts=0
# USAGE: yank [-t target-pane]
# DESCRIPTION: Redraw a pane with two-letter hints over commands, file names and paths; typing a hint copies that text.
# Meant to run in a popup laid exactly over the pane (scratchpad/popup), so the hints sit on the text they copy.
# Keys: a two-letter hint copies, <Esc> clears a half-typed hint, q quits.
# After the first key only the hints that still match stay highlighted.

require 'io/console'
require 'open3'
require 'optparse'
require 'set'

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
# A path that doesn't exist gets the same pair in dark and light red.
HIGHLIGHT_COLOR = "\e[38;5;255;48;5;24m"
HINT_COLOR = "\e[1;38;5;0;48;5;117m"
MISSING_HIGHLIGHT_COLOR = "\e[38;5;255;48;5;124m"
MISSING_HINT_COLOR = "\e[1;38;5;0;48;5;210m"

# ls is /usr/bin/ls, see ~/.bashrc or ../tmux, not https://host/a or a/b, and /a/b.py:12 is /a/b.py
# Absolute, ~/, ./ and ../ paths; the lookbehind skips the "/b" in "a/b" or "日本/b", and find_paths handles ":".
PATH_PATTERN = %r{(?<![\p{Word}.~/-])(?:~|\.\.?)?/[^\s'"`:;,|()<>\[\]\{\}]*}

# "/a/b." and "is it /a/b?" end a sentence, so the punctuation goes; "/a/.." and "/a/." keep their dots.
SENTENCE_END = %r{(?<=[^./])[.?!]+\z}

# Bare prefixes name no file worth copying.
PATH_PREFIXES = Set['/', '~/', './', '../']

# A pane running one of these is on another host, so local existence checks would mark its paths missing.
REMOTE_COMMANDS = Set['ssh', 'mosh-client']

# A guess: a screen of local stats takes a few milliseconds, and 0.3s is about when the popup feels slow.
EXISTS_TIMEOUT_SECONDS = 0.3

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

# Return { text, row, column, missing } for each line matching regex; column is in terminal cells.
def find_matches(lines, regex, group)
	matches = []
	lines.each_with_index do |line, row|
		match = line.match(regex)
		next unless match
		before_match = line[0...match.begin(group)]
		matches.append({ text: match[group], row: row, column: display_width(before_match), missing: false })
	end
	return matches
end

# find_paths(['ls is /usr/bin/ls']) -> [{ text: '/usr/bin/ls', row: 0, column: 6, missing: false }]
# find_paths(['PATH=/a:/b see https://host/c']) -> '/a' and '/b' only
def find_paths(lines)
	matches = []
	lines.each_with_index do |line, row|
		previous_end = nil
		line.scan(PATH_PATTERN) do
			match = Regexp.last_match
			start = match.begin(0)
			# PATH=/usr/bin:/bin chains paths with ":", but "host:/a" and "https://host" are not local paths.
			after_colon = start > 0 && line[start - 1] == ':'
			chained = previous_end == start - 1
			previous_end = match.end(0)
			next if after_colon && !chained
			text = match[0].sub(SENTENCE_END, '')
			next if PATH_PREFIXES.include?(text)
			column = display_width(line[0...start])
			matches.append({ text: text, row: row, column: column, missing: false })
		end
	end
	return matches
end

# check_missing(['/usr/bin/ls', '/no/such']) -> [false, true]
# A stat on a hung NFS mount never returns, so a child does the checks and unanswered files count as present.
def check_missing(files)
	return [] if files.empty?
	reader, writer = IO.pipe
	child_pid = fork do
		reader.close
		writer.sync = true
		files.each { |file| writer.puts(File.exist?(file) ? 'present' : 'missing') }
		exit!(0)
	end
	writer.close

	answers = []
	deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + EXISTS_TIMEOUT_SECONDS
	while answers.length < files.length
		seconds_left = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
		break if seconds_left <= 0
		break unless reader.wait_readable(seconds_left)
		answer = reader.gets
		break if answer.nil?
		answers.append(answer.chomp == 'missing')
	end
	reader.close

	if answers.length < files.length
		num_unchecked = files.length - answers.length
		message("WARNING: yank: path checks passed #{EXISTS_TIMEOUT_SECONDS}s, so #{num_unchecked} paths stay blue; check for a hung mount")
		Process.kill(:KILL, child_pid)
	end
	Process.detach(child_pid)
	return files.each_index.map { |index| answers.fetch(index, false) }
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
		highlight_color = match[:missing] ? MISSING_HIGHLIGHT_COLOR : HIGHLIGHT_COLOR
		hint_color = match[:missing] ? MISSING_HINT_COLOR : HINT_COLOR
		screen.append("#{position}#{highlight_color}#{match[:text]}#{RESET}")
		screen.append("#{position}#{hint_color}#{hint}#{RESET}")
	end
	$stdout.write(screen.join)
	$stdout.flush
	return nil
end


# ==============================================================================
# CAPTURE PANE
# ==============================================================================
target_arguments = []
target_arguments.append('-t', options[:target]) if options[:target]

capture_arguments = []
capture_arguments.append('capture-pane', '-p', '-e')
capture_arguments.append(*target_arguments)
pane_contents, error_output, status = tmux(capture_arguments)
abort "ERROR: yank: tmux capture-pane failed (#{error_output.strip}); check that -t names a live pane" unless status.success?

# The popup starts in the client's directory, so relative paths need the pane's own.
# ssh	/home/todd/project
pane_output, error_output, status = tmux(['display-message', '-p', *target_arguments, "\#{pane_current_command}\t\#{pane_current_path}"])
abort "ERROR: yank: tmux display-message failed (#{error_output.strip}); check that -t names a live pane" unless status.success?
pane_command, pane_dir = pane_output.chomp.split("\t", 2)

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

# commit a2414681c265ffc8fe98c6f40d7cf0e71a93c7a4
# 27ad5ac [4 minutes ago ] Todd Yamakawa        : (HEAD -> master) 📝 README.md: Point M-y at scratchpad/yank.
# * | 737aca2 ✨ scripts/scratchpad/yank.rb: Add hints for paths.
# The hash must hold a letter, so a line like "1234567 bytes" from wc is not taken for a commit.
all_matches['git'] = find_matches(lines, /\A[*|\/\\ ]*(?:commit )?(?=\d*[a-f])([0-9a-f]{7,40})\b/, 1)

# A symlink target already has a file hint, so a path that starts on a taken cell gets no second one.
taken_cells = Set.new
all_matches.each_value do |matches|
	matches.each { |match| taken_cells.add([match[:row], match[:column]]) }
end
paths = find_paths(lines)
paths = paths.reject { |match| taken_cells.include?([match[:row], match[:column]]) }

# Only a local pane's paths can be checked, so a remote pane's paths all stay blue.
unless REMOTE_COMMANDS.include?(pane_command)
	full_files = paths.map { |match| File.expand_path(match[:text], pane_dir) }
	missing = check_missing(full_files)
	paths.each_with_index { |match, index| match[:missing] = missing[index] }
end

# Paths join the file list so every file-like hint starts with f.
all_matches['file'].concat(paths)


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
