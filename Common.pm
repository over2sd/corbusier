# Miscellaneous common functions
### 14-7-17 (from a previous library)
use strict;
use warnings;

package Common;

use base 'Exporter';
our @EXPORT = qw( findIn loadSeedsFrom selectWidth getColors getColorsbyName between nround findClosest vary lineNo);

use List::Util qw( min max );
use POSIX qw( floor );

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

=item vary()
	Vary an input ($base) by +/- an amount ($variance).
	Returns altered input.
=cut
sub vary {
	my ($base,$variance) = @_;
	$base -= $variance;
	$base += rand(2 * $variance);
	return $base;
}

sub listSort {
	my ($index,@array) = @_;
	if (@array <= 1) { return \@array,$index; } # already sorted if length 0-1
	unless (defined $index) { $index = (); }
	my (@la,@ra,@li,@ri);
	my $mid = floor(@array/2) - 1;
#	print "Trying: $mid/$#array/" . $#{$index} . "\n";
	@la = ($mid <= $#array ? @array[0 .. $mid] : @la);
	@ra = ($mid + 1 <= $#array ? @array[$mid + 1 .. $#array] : @ra);
	@li = ($mid <= $#{$index} ? @$index[0 .. $mid] : @li);
	@ri = ($mid + 1 <= $#{$index} ? @$index[$mid + 1 .. $#{$index}] : @ri);
	my ($la,$li) = listSort(\@li,@la);
	my ($ra,$ri) = listSort(\@ri,@ra);
	my ($outa,$outi) = listMerge($la,$ra,$li,$ri);
	return ($outa,$outi);
}

sub listMerge {
	my ($left,$right,$lind,$rind) = @_;
	my (@oa,@oi);
	while (@$left or @$right) {
		if (@$left and @$right) {
			if (@$lind[0] < @$rind[0]) {
				push(@oa,shift(@$left));
				push(@oi,shift(@$lind));
			} else {
				push(@oa,shift(@$right));
				push(@oi,shift(@$rind));
			}
		} elsif (@$left) {
			push(@oa,shift(@$left));
			if (@$lind) { push(@oi,shift(@$lind)); }
		} elsif (@$right) {
			push(@oa,shift(@$right));
			if (@$rind) { push(@oi,shift(@$rind)); }
		}
	}
	return \@oa,\@oi;
}

sub lineNo {
	my $depth = shift;
	$depth = 1 unless defined $depth;
	use Carp qw( croak );
	my @loc = caller($depth);
	my $line = $loc[2];
	my $file = $loc[1];
	@loc = caller($depth + 1);
	my $sub = $loc[3];
	if ($sub ne '') {
		@loc = split("::",$sub);
		$sub = $loc[$#loc];
	} else {
		$sub = "(MAIN)";
	}
	return qq{ at line $line of $sub in $file.\n };
}

sub getBit { # returns bool
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return ($mask & $pos) == $pos ? 1 : 0;
}

sub setBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return $mask | $pos;
}

sub unsetBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return $mask ^ $pos;
}

sub toggleBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	$pos = $mask & $pos ? $pos : $pos * -1;
	return $mask + $pos;
}

1;
