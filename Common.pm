# Miscellaneous common functions
### 14-7-17 (from a previous library)
use strict;
use warnings;

package Common;

use base 'Exporter';
our @EXPORT = qw( findIn );

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

1;