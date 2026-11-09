#!/usr/bin/env perl
# USAGE: yank [-t target-pane]
# DESCRIPTION: Redraw a pane with two-letter hints over commands and file names; typing a hint copies that text.
# Meant to run in a popup laid exactly over the pane (scratchpad/popup), so the hints sit on the text they copy.
# Keys: a two-letter hint copies, <Esc> clears a half-typed hint, q quits.
# After the first key only the hints that still match stay highlighted.
use strict;
use warnings;
use utf8;
use Getopt::Long;

binmode STDIN,  ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
$| = 1;

# ==============================================================================
# ARGUMENTS
# ==============================================================================
my $target;
GetOptions('t|target=s' => \$target) or die "USAGE: yank [-t target-pane]\n";


# ==============================================================================
# ENVIRONMENT
# ==============================================================================
my $clear_screen = "\e[H\e[2J";
my $hide_cursor  = "\e[?25l";
my $show_cursor  = "\e[?25h";
my $reset        = "\e[0m";

# The whole match is highlighted in muted blue and its hint sits on its first two cells in light blue.
my $highlight_color = "\e[38;5;255;48;5;24m";
my $hint_color      = "\e[1;38;5;0;48;5;117m";

# 'q' quits, so it can't be a hint character.
my @hint_characters = split //, 'fdsavcxzrewtgb1234567890jklmuiopyhn';

my $ansi_escape = qr/\e(?:[@-Z\\\-_]|\[[0-?]*[ -\/]*[@-~])/;


# ==============================================================================
# HELPERS
# ==============================================================================
# Returns the command's output and exit code; takes an array ref so the arguments read as one list.
sub tmux {
	my ($arguments) = @_;
	open(my $pipe, '-|', 'tmux', @$arguments) or return ('', 127);
	binmode $pipe, ':encoding(UTF-8)';
	my $output = do { local $/; <$pipe> } // '';
	close $pipe;
	return ($output, $? >> 8);
}

sub message {
	my ($text) = @_;
	tmux(['display-message', $text]);
	return;
}

# East Asian wide characters take two terminal cells, so a plain length() would put later hints too far left.
sub display_width {
	my ($text) = @_;
	my $num_wide = () = $text =~ /[\p{East_Asian_Width=Wide}\p{East_Asian_Width=Fullwidth}]/g;
	return length($text) + $num_wide;
}

# Returns one { text, row, column } hash per line matching the pattern; column is in terminal cells.
sub find_matches {
	my ($lines, $pattern, $group) = @_;
	my @matches;
	for my $row (0 .. $#$lines) {
		my $line = $lines->[$row];
		next unless $line =~ $pattern;

		# Read the match positions before display_width runs its own regex and overwrites them.
		my $start = $-[$group];
		my $text  = substr($line, $start, $+[$group] - $start);
		push @matches, { text => $text, row => $row, column => display_width(substr($line, 0, $start)) };
	}
	return @matches;
}

# Redraw the pane, then highlight every match whose hint starts with what has been typed so far.
sub draw {
	my ($colored_lines, $hints, $typed) = @_;

	# Place every row and hint by absolute position; a stray newline on the last row would scroll the popup.
	my @screen = ($hide_cursor, $clear_screen);
	for my $row (0 .. $#$colored_lines) {
		push @screen, sprintf("\e[%d;1H%s%s", $row + 1, $colored_lines->[$row], $reset);
	}
	for my $hint (sort keys %$hints) {
		next unless index($hint, $typed) == 0;
		my $match    = $hints->{$hint};
		my $position = sprintf("\e[%d;%dH", $match->{row} + 1, $match->{column} + 1);
		push @screen, "$position$highlight_color$match->{text}$reset";
		push @screen, "$position$hint_color$hint$reset";
	}
	print join('', @screen);
	return;
}


# ==============================================================================
# CAPTURE PANE
# ==============================================================================
my @capture_arguments = ('capture-pane', '-p', '-e');
push @capture_arguments, '-t', $target if defined $target;
my ($pane_contents, $exit_code) = tmux(\@capture_arguments);
die "ERROR: yank: tmux capture-pane failed; check that -t names a live pane\n" if $exit_code != 0;

# One entry per pane row; keep blank rows so row numbers match the pane.
my @colored_lines = split /\n/, $pane_contents, -1;
pop @colored_lines if @colored_lines && $colored_lines[-1] eq '';
my @lines = map { s/$ansi_escape//gr } @colored_lines;


# ==============================================================================
# FIND MATCHES
# ==============================================================================
my %all_matches;

# todd 755 bin main » <command>
$all_matches{command} = [find_matches(\@lines, qr/^.*»\s*(\S.*)/, 1)];

# lrwxrwxrwx 1 todd group   11 Jan  1 23:59 file -> /path/to/file
# drwxrwxrwx 1 todd group    0 Jan  1 23:59 dir/
# -rw-r--r-- 1 todd group  10K Jan  1 23:59 file.txt
$all_matches{file} = [find_matches(\@lines, qr/^[-dl]([-r][-w][-x]){3}.* (\S+)/, 2)];


# ==============================================================================
# GENERATE HINTS
# ==============================================================================
my %hints;
for my $kind (keys %all_matches) {
	my @matches = @{ $all_matches{$kind} };
	my $prefix  = substr($kind, 0, 1);

	# REVISIT: Support more matches than hint characters.
	my $num_hinted = @matches < @hint_characters ? @matches : @hint_characters;
	for my $index (0 .. $num_hinted - 1) {
		$hints{ $prefix . $hint_characters[$index] } = $matches[$index];
	}
}


# ==============================================================================
# READ KEYS
# ==============================================================================
# stty reads and sets the terminal on stdin; END restores it on every exit path, including die.
chomp(my $saved_terminal = qx(stty -g));
system('stty', 'raw', '-echo');
END {
	local $?;
	if ($saved_terminal) {
		system('stty', $saved_terminal);
		print $show_cursor;
	}
}

my $typed = '';
draw(\@colored_lines, \%hints, $typed);
while (defined(my $key = getc(STDIN))) {
	exit 0 if $key eq 'q';
	if ($key eq "\e") {
		$typed = '';
		draw(\@colored_lines, \%hints, $typed);
		next;
	}

	my @candidates = grep { index($_, $typed . $key) == 0 } keys %hints;
	next unless @candidates;
	$typed .= $key;
	if (!exists $hints{$typed}) {
		draw(\@colored_lines, \%hints, $typed);
		next;
	}

	my $text = $hints{$typed}{text};
	tmux(['set-buffer', $text]);

	# scripts/run puts scripts/ on PATH, so copy-pipe is the same script copy-mode <y> uses.
	my $copied = 0;
	if (open(my $clipboard, '|-', 'copy-pipe')) {
		binmode $clipboard, ':encoding(UTF-8)';
		print {$clipboard} $text;
		$copied = close $clipboard;
	}
	message($copied ? "Copied: $text" : 'WARNING: yank: copy-pipe failed; copied to a tmux buffer only');
	exit 0;
}
