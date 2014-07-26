print "This program does nothing. It serves as storage for bits of code that didn't work out as intended but may prove useful in another place.\n";
exit(0);

# divide highways among remaining junctions
	my $rem = $hiw - (int($hiw/$divisor) * $divisor);	
	my @histogrow;
# if more than $hiw junctions, put one in each slot, then cut off after $hiw junctions.
	foreach my $i (0 .. $divisor) {
		push(@histogrow,int($hiw/$divisor) + ($i > 0 ? 0 : $rem));
	}
	my $i = 0;
	my @exits;
#	use Data::Dumper;
#	print Dumper @histogrow;
	foreach my $i (0 .. $#sqs) {
# shift out a vertex and a number of highways to grow from it
		my $nh = shift @histogrow;
#			print "Edge: $exside ";
		}
		while ($nh > 0) {
# (x (or y for E/W) +/- .25x)
##			my $base = ($xfirst ? $v->x() : $v->y());
#			print "Edge: $base ";
#			$base = $base - floor($base / 4) + int(rand($base/2)) * ($xfirst ? $fx : $fy);
#			$base = $base - floor($base/4) + int(rand($rng)) * ($xfirst ? $fx : $fy);
#			print "=> $base :: $edge\n";
			$nh -= 1;
		}
		push(@joins,$v);
		if ($i > 100) { exit(-1); }
	}
	foreach my $v (@exits) {
		my $exitx = $v->x();
		my $exity = $v->y();
#	check distance from exit to each join
		$lowindex = Points::getClosest($exitx,$exity,\@joins);
	#TODO: Decide if another check should be made here and a waypoint added half-way
	#  for other highways to connect to, so we don't have many long highways near each other?
		my $line = Segment->new($numroutes);
		$line->set_ends($exitx,$joins[$lowindex]->x(),$exity,$joins[$lowindex]->y());
		$numroutes += 1;
		$hiw -= 1;
	}
