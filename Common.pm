# Miscellaneous common functions
### 14-7-17 (from a previous library)
use strict;
use warnings;

package Common;

use base 'Exporter';
our @EXPORT = qw( findIn loadSeedsFrom selectWidth );

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

sub loadSeedsFrom {
	my @ls;
	my $fn = shift;
	my $fail = 0;
    open (INFILE, "<$fn") || ($fail = 1);
	if ($fail) { print "Dying of file error: $! Woe, I am slain!"; exit(-1); }
	while(<INFILE>) {
		my($line) = $_;
		chomp($line);
		if($line =~ m/^((, ?)?-?\d)*$/) {
			my @nums = split(',',$line);
			foreach my $i (@nums) {
				push(@ls,int($i));
			}
		} elsif($line =~ m/^-?\d\s*\.\.\s*-?\d$/) { # 1 .. 10 sequence
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

1;