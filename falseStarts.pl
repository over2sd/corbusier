print "This program does nothing. It serves as storage for bits of code that didn't work out as intended but may prove useful in another place.\n";
exit(0);

# ensure enough junctions for highways to not look like a panicked exodus
	if ($divisor < ($hiw / 3)) {
		my @waypoints;
		my $needed = $hiw / 3 - $divisor;
		print "Adding $needed waypoints.";
		my $perjoin = int($needed / $divisor) or 1;
		foreach my $i (0 .. $#sqs) {
		# if more than two, ignore the one most central from list
			if ($i == $lowindex and $#sqs != 1) { print "'"; next; }
			my $fromhere = 0;
			my $xbound = int($w/10);
			my $ybound = int($h/10);
			my $xdiff0 = $sqs[$i]->x();
			my $xdiffn = $w - $sqs[$i]->x();
			my $ydiff0 = $sqs[$i]->y();
			my $ydiffn = $h - $sqs[$i]->y();
			my $xbase = 0;
			my $ybase = 0;
			my $xiscentered = 0;
			my $xf = $xdiff0 / $xdiffn;
			my $yf = $ydiff0 / $ydiffn;
			# divide the map into 8 directions
			if ($xf < 0.493) {
				$xbase = int($w / 10);
				$xbound = int(0.8 * ($xdiff0 - $xbase));
			} elsif ($xf > 1.941) {
				$xbase = $xdiff0 + int($w/10);
				$xbound = int(0.8 * $xdiffn - int($w/10));
			} else {
				$xiscentered = 1;
				$xbase = $xdiff0 - int($w/20);
				$xbound = int($w/10);
			}
			if ($yf < 0.493) {
				$ybase = int($h / 10);
				$ybound = int(0.8 * ($ydiff0 - $ybase));
			} elsif ($yf > 1.941 or $xiscentered ) { # We don't want to toss them both in the center, so y can't center if x does.
				$ybase = $ydiff0 + int($h/10);
				$ybound = int(0.8 * $ydiffn - int($h/10));
			} else {
				$ybase = $ydiff0 - int($h/20);
				$ybound = int($h/10);
			}
			while ($fromhere < $perjoin) {
				if (@waypoints >= $needed) { last; }
				my $wp = Vertex->new();
				my $success = Points::placePoint($wp,$xbound,$xbase,$ybound,$ybase,\@waypoints,($hiw > 12 ? 5 : 20),5 * $hiw);
				if ($wp->x() != 0 and $wp->y() != 0 and $success) {
					$wp->immobilize();
					push(@waypoints,$wp);
					$fromhere++;
					print ".";
				} else {
					if ($debug) { print "*&^#"; }
				}
			}
		}
		foreach my $vi (0 .. $#waypoints) { # connect new waypoints to old junctions
			my $line = Segment->new();
			my $closest = Points::getClosest($waypoints[$vi]->x(),$waypoints[$vi]->y(),\@sqs);
			$line->set_ends($waypoints[$vi]->x(),$sqs[$closest]->x(),$waypoints[$vi]->y(),$sqs[$closest]->y());
			$line->immobilize();
			push(@irts,$line);
		}
		push(@sqs,@waypoints);
		$divisor = $#sqs; 
		if ($divisor == 1) { # exactly two junctions
			$divisor++;
		}
		print "\n";
	}
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
#		highways will go from exit to closest join
	#TODO: Decide if another check should be made here and a waypoint added half-way
	#  for other highways to connect to, so we don't have many long highways near each other?
		my $line = Segment->new($numroutes);
		$line->set_ends($exitx,$joins[$lowindex]->x(),$exity,$joins[$lowindex]->y());
		$numroutes += 1;
		$hiw -= 1;
	}
