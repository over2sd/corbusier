# Miscellaneous common functions
### 14-7-17 (from a previous library)
use strict;
use warnings;

package Common;

use base 'Exporter';
our @EXPORT = qw( findIn loadSeedsFrom selectWidth getColors getColorsbyName between nround findClosest );

use List::Util qw( min max );

my $debug = 0;



sub findIn {
	my ($v,@a) = @_;
	if ($debug > 0) {
		use Data::Dumper;
		print ">>".Dumper @a;
		print "($v)<<";
	}
	unless (defined $a[$#a] and defined $v) {
		use Carp qw( croak );
		my @loc = caller(0);
		my $line = $loc[2];
		@loc = caller(1);
		my $file = $loc[1];
		my $func = $loc[3];
		croak("FATAL: findIn was not sent a \$SCALAR and an \@ARRAY as required from line $line of $func in $file. Caught");
		return -1;
	}
	my $i = 0;
	while ($i < scalar @a) {
		print ":$i:" if $debug > 0;
		if ("$a[$i]" eq "$v") { return $i; }
		$i++;
	}
	return -1;
}

# new
sub loadSeedsFrom {
	my @ls;
	my $fn = shift;
	my $fail = 0;
    open (INFILE, "<$fn") || ($fail = 1);
	if ($fail) { print "Dying of file error: $! Woe, I am slain!"; exit(-1); }
	while(<INFILE>) {
		my($line) = $_;
		chomp($line);
		if ($line =~ m/^((, ?)?-?\d)*$/) {
			my @nums = split(',',$line);
			foreach my $i (@nums) {
				push(@ls,int($i));
			}
		} elsif ($line =~ m/^-?\d+\s?\.\.\s?-?\d+$/) { # 1 .. 10 sequence
			$line =~ s/\.\./;/;
			my @nums = split(';',$line); # TODO: sanity checking here
			my @range = (int($nums[0]) .. int($nums[1]));
			push(@ls,@range);
		} elsif ($line eq '') {
			# Skipping empty line
		} else {
			print "Bad seed in line: $line\n";
		}
	}
	return @ls;
}

=item selectWidth()
	Given an increment and a total number of units in the rectangle, returns a logical width for smallest total rectangle area.
=cut
# new for this project
sub selectWidth {
	my $w = 1;
	my ($increment,$total) = @_;
	my @breaks = (0,1,4,9,16,25,36,49,64,81,100,121,144);
	foreach my $b (0 .. $#breaks) {
		if ($total <= $breaks[$b]) {
			$w = $b;
			last;
		} else {
			# do nothing
		}
	}
	#print "Width: $w * $increment";
	$w *= $increment; # for units, use increment = 1.
	#print " = $w\n";
	return $w;
}

# from same previous library
sub getColorsbyName {
	my $name = shift;
	my @colnames = qw( base red green yellow blue purple cyan ltred ltgreen ltyellow ltblue pink ltcyan white bluong blkrev gray );
	my $ccode = -1;
	++$ccode until $ccode > $#colnames or $colnames[$ccode] eq $name;
	$ccode = ($ccode > $#colnames) ? 0 : $ccode;
	return getColors($ccode);
}

# from same previous library
sub getColors{
	if (0) { # TODO: check for terminal color compatibility
		return "";
	}
	my @colors = ("\033[0;37;40m","\033[0;31;40m","\033[0;32;40m","\033[0;33;40m","\033[0;34;40m","\033[0;35;40m","\033[0;36;40m","\033[1;31;40m","\033[1;32;40m","\033[1;33;40m","\033[1;34;40m","\033[1;35;40m","\033[1;36;40m","\033[1;37;40m","\033[0;34;47m","\033[7;37;40m","\033[1;30;40m");
	my $index = shift;
	if ($index >= scalar @colors) {
		$index = $index % scalar @colors;
	}
	if (defined($index)) {
		return $colors[int($index)];
	} else {
		return @colors;
	}
}

# new for this project
sub between {
	my ($unk,$bound1,$bound2,$exclusive,$fuzziness) = @_;
	$fuzziness = 0 if not defined $fuzziness;
	if ($unk < min($bound1,$bound2) - $fuzziness or $unk > max($bound1,$bound2) + $fuzziness) {
		return 0; # out of range
	}
	if (defined $exclusive and $exclusive == 1 and ($unk == $bound1 or $unk == $bound2)) {
		return 0; # not between but on one boundary
	}
	return 1; # in range
}

sub nround {
	my ($prec,$value) = @_;
	use Math::Round qw( nearest );
	my $target = 1;
	while ($prec > 0) { $target /= 10; $prec--; }
	while ($prec < 0) { $target *= 10; $prec++; } # negative precision gives 10s, 100s, etc.
	if ($debug) { print "Value $value rounded to $target: " . nearest($target,$value) . ".\n"; }
	return nearest($target,$value);
}

sub findClosest {
	my ($v,@ordered) = @_;
	if ($debug > 0) {
		use Data::Dumper;
		print ">>".Dumper @ordered;
		print "($v)<<";
	}
	unless (defined $ordered[$#ordered] and defined $v) {
		use Carp qw( croak );
		my @loc = caller(0);
		my $line = $loc[2];
		@loc = caller(1);
		my $file = $loc[1];
		my $func = $loc[3];
		croak("FATAL: findClosest was not sent a \$SCALAR and an \@ARRAY as required from line $line of $func in $file. Caught");
		return -1;
	}
	my $i = 0;
	my $diffunder = $v;
	while ($i < scalar @ordered) {
		print ":$i:" if $debug > 0;
		if ($ordered[$i] < $v) {
			$diffunder = $v - $ordered[$i];
			$i++;
			next;
		} else {
			my $diffover = $ordered[$i] - $v;
			if ($diffover > $diffunder) { return $i - 1; }
			return $i;
		}
	}
	return -1;
}


1;