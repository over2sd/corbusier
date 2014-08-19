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

##sub branchmap {
	if ($debug) { print "branchmap(@_)\n"; }
	my ($hiw,$sec,$rat,$max,$forcesquare) =  @_;
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	my $numroutes = 0;
	my @sqs;
	my @rts;
	my @poi;
	my $mxj = $hiw > 20 ? 11 : $hiw > 10 ? 7 : 5;
	my $joins = floor(rand($mxj)) + 1; # choose number of intersections
	if ($debug) { print "  Joins: " . $joins . "/" . $mxj . "\n"; }


## genSqs random mode
	my $w = $mdconfig{width};
	my $h = $mdconfig{height};
	$mxj = floor($w / 8);
	my $myj = floor($h / 8);
	foreach my $i (0 .. $joins - 1) { # choose joining point(s)
		my ($d,$j,$x,$y) = 0,0,0,0;
		my $v = Vertex->new(Points::useRUID());
		my $success = Points::placePoint($v,2 * $mxj,3 * $mxj,2 * $myj,3 * $myj,\@sqs,(min($w,$h) > 125 ? 20 : 5),$joins * 10);
		if ($v->x() != 0 and $v->y() != 0 and $success) {
		   push(@sqs,$v);
		} else {
			if ($debug) { print "!@%&"; }
		}
	}
	print "Squares: " . scalar(@sqs) . "\n";
## end genSqs


	# connect all village squares
#	my ($lowindex,@irts) = connectSqs(@sqs,@waypoints);;
	my @irts;
	my $lowindex = 0;


## connectSqs random mode?
	# find point closest to center
	# later, add options to have "center" be closest to one corner, instead, or a random point instead of the most central.
	my @center = (floor($w / 2),floor($h / 2));
	$lowindex = Points::getClosest(@center,\@sqs);
	foreach my $i (0 .. $#sqs) {	 # link point to all other points
		if ($i != $lowindex) {
		   my $line = Segment->new($numroutes);
		   $numroutes += 1;
			# This line is to prepare for comparisons:
			$line->set_ends($sqs[$i]->x(),$sqs[$lowindex]->x(),$sqs[$i]->y(),$sqs[$lowindex]->y());
			$line->name(sprintf("Road%d",$i));
			moveIfNear($line,$i,$lowindex,20,@sqs);
			undoIfIsolated($line,\@irts,$sqs[$lowindex]->x(),$sqs[$lowindex]->y());
			$line->immobilize();
#			  Save these highways to a separate list that will be added to the end of the routes, so other roads don't come off them.
		   push(@irts,$line)
		}
		if ($i == $#sqs and $numroutes < $hiw) { $i = 0; } elsif ($numroutes >= $hiw) { last; } #Another go around, or leave early
	}
## end section


# place highways #############
	print "\nPlacing highways..";
# count junctions
	my @joins;
	my $divisor = $#sqs;
	if ($divisor < 2) { # fewer than three junctions
		$divisor++;
	}
# If more than one highway per join, grow highways with weight toward even spacing around the map:
	print "Dividing $hiw among $divisor junctions...";
	if ($divisor < $hiw) {
# ensure enough junctions for highways to not look like a panicked exodus
		if ($divisor < ($hiw / 3)) {
			my @waypoints;
			my $needed = $hiw / 3 - $divisor;

####: to be folded into village square generation
### waypoint generation (old method)
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
					my $wp = Vertex->new(Points::useRUID());
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
				$waypoints[$vi]->clip(0,0,$w,$h);
				$line->set_ends($waypoints[$vi]->x(),$sqs[$closest]->x(),$waypoints[$vi]->y(),$sqs[$closest]->y());
				$line->immobilize();
				push(@irts,$line);
			}
			push(@sqs,@waypoints);
			$divisor = $#sqs; 
			if ($divisor == 1) { # exactly two junctions
				$divisor++;
			}
#### end of section

		}
		my @exits;
		my $bearingrange = 360 / $hiw;
		my $bearingbase = 0;
		while (scalar @exits < $hiw) {
			my $bearing = $bearingbase + rand($bearingrange);
			my $ev = Points::interceptFromAz($bearing,$w,$h); # running from center
			$ev->clip(0,0,$w,$h);
#	check distance from exit to each join
			my $wayindex = Points::getClosest($ev->x(),$ev->y(),\@sqs);
#		highways will go from exit to closest join
			my $line = Segment->new(undef,sprintf("Road on %.2f",$bearing),$ev->x(),$sqs[$wayindex]->x(),$ev->y(),$sqs[$wayindex]->y());
			moveIfNear($line,-1,$wayindex,20,@sqs);
			
			if ($debug > 1) { print "\t" . $line->describe(1) . "\n"; }
			push(@exits,$ev);
			$bearingbase += $bearingrange;
#			$bearingbase = $bearing + 15;
#			$bearingrange = (360 - $bearingbase) / (($hiw - scalar(@exits)) or 1); # only you can prevent div/0!
			push(@rts,$line);
		}
		print "Function incomplete!\n";
	} else { # not ($divisor >= $hiw)
# If fewer than one highway per join, just grow a highway from each to the nearest edge:
		my @exits;
		my @edges = ();
		foreach my $i (0 .. $#sqs) {
			# if more than two, ignore the one most central from list
			if ($i == $lowindex and $#sqs > 1) { print "'"; next; }
			print ".";
			my $v = $sqs[$i];
#		print ($v  or "undef") . " ";
# find closest compass direction
			my $exside = Points::closestCardinal($v->x(),$v->y(),$w,$h);
			if ($divisor < 4) { # for small number of junctions, don't let the exits cluster on one side.
				while (@edges and Common::findIn($exside,@edges) != -1) {
					$exside += 1; print ":";
					if ($exside > 7) { $exside -= 8; }
				}
				push(@edges,$exside);
			}
			my ($fx,$fy,$xfirst,$edge) = (1,1,1,0);
			if ($debug > 1) { print "Highway $hiw is exiting: $exside... \n"; }
			$hiw -= 1;
			my ($rng,$base) = (0,0);
			for ($exside) {
				if (/1/) { $rng = int($w/3); $base = int($w * 0.67); }
				elsif (/2/) { $fx = -1; $xfirst = 0; $edge = $w; $rng = int($h/3); }
				elsif (/3/) { $fx = -1; $xfirst = 0; $edge = $w; $rng = int($h/3); $base = int($w/3); }
				elsif (/4/) { $fx = -1; $xfirst = 0; $edge = $w; $rng = int($h/3); $base = int($w * 0.67); }
				elsif (/5/) { $fx = -1; $fy = -1; $edge = $h; $rng = int($w/3); $base = int($w * 0.67); }
				elsif (/6/) { $fx = -1; $fy = -1; $edge = $h; $rng = int($w/3); $base = int($w/3); }
				elsif (/7/) { $fx = -1; $fy = -1; $edge = $h; $rng = int($w/3); }
				elsif (/8/) { $fy = -1; $xfirst = 0; $rng = int($h/3); $base = int($w * 0.67); }
				elsif (/9/) { $fy = -1; $xfirst = 0; $rng = int($h/3); $base = int($w/3); }
				elsif (/10/) { $fy = -1; $xfirst = 0; $rng = int($h/3); }
				else { $rng = int($w/3); }
			}
# grow a highway to a point on the edge
			my ($x,$y);
			my $mate = $edge;
			$base += int(rand($rng));
			if ($base > ($xfirst ? $w : $h)) {
				my $overage = $base - ($xfirst ? $w : $h) * ($xfirst ? $fy : $fx); # mate, so reverse order
				$mate += $overage;
				$base = ($xfirst ? $w : $h);
			}
			($x,$y) = ($xfirst ? ($base,$mate) : ($mate,$base));
			if ($x > $w or $y > $h) {
				print "For " . $v->id() . ": ($x,$y) $exside\n";
			}
# If total is greater than h (or w), trim, and push away from edge with excess
			foreach my $ev (@exits) {
				my $mindist = int(($xfirst ? $w : $h) / 15);
				if (abs(($xfirst ? $ev->x() - $x : $ev->y() - $y)) < $mindist) {
					if ($debug > 8) { print "--nudge--(" . $ev->x() . "," . $ev->y() . ")><($x,$y)>>"; } else { print "^"; }
					my $mod;
					my $dist = ($xfirst ? $ev->x() - $x : $ev->y() - $y);
					($dist < 0 ? $mod = int(rand(4)) + $mindist - $dist : $mod = -int(rand(4)) -$mindist + $dist);
					if ($xfirst) { $x += $mod; }
					else { $y += $mod; }
					if ($x > $w) { $x = $w - 5; }
					if ($x < 0) { $x = int(rand(10)) + 5; }
					if ($y > $h) { $y = $h - 5; }
					if ($y < 0) { $y = int(rand(10)) + 5; }
					if ($debug > 8) { print "($x,$y)--"; }
# TODO: This function seriously needs improvement.
					if (abs(($xfirst ? $ev->x() - $x : $ev->y() - $y)) < $mindist) {
						print "Xnudge...(" . $ev->x() . "," . $ev->y() . ")>>";
						my $dist = ($xfirst ? $ev->x() - $x : $ev->y() - $y);
						($dist > 0 ? $mod = $mindist + 2 - $dist : $mod = -($mindist + 2) + $dist);
						($xfirst ? $ev->x($ev->x() + $dist) : $ev->y($ev->y() + $dist));
						print "(" . $ev->x() . "," . $ev->y() . ")...";
					}
				}
				if ($debug > 1) { print "Edge pair for (" . $ev->x() . "," . $ev->y() . ") is now ($x,$y).\n"; }
			}
			my $e = Vertex->new(Points::useRUID());
			$e->move($x,$y);
			$e->clip(0,0,$w,$h);
			push(@exits,$e);
			my $line = Segment->new($numroutes);
			$line->set_ends($e->x(),$v->x(),$e->y(),$v->y());
			moveIfNear($line,-1,-1,85,@sqs);
			$numroutes += 1;
#	add highway to route list
			push(@rts,$line)
		}
	}
#	place secondaries
	my @secondaries = branchSecondaries($sec,$forcesquare,@rts);
	$numroutes += scalar(@secondaries);
	push(@rts,@secondaries);
#place smaller roads
### This needs a new function...
	my @sideroads = branchSides($rat,@secondaries);
	$numroutes += scalar(@sideroads);
	push(@rts,@sideroads);
	# add in internal routes
	push(@rts,@irts);
	return $numroutes,@rts;
}



	print "Fracs: @fracs \n";
	my $i = scalar @fracs;
	my $lastshift = 0;
	while ($i > 0) {
		my $range = (1.00 - $current) * $fracs[--$i];
		my $p = rand($range);
		my $dist = $p + $current;
		my $off = 1 / (abs($div/2 - $i) + 1);
		my $maxshift = 60 * $off;
		print "Max: $maxshift \n";
		my $thisshift = rand(60) - 30 + $lastshift;
		if ($thisshift > $maxshift / 3) { $thisshift = $maxshift - ($thisshift - $maxshift); }
		if ($thisshift < 0 - $maxshift / 3) { $thisshift = $thisshift + (0 - $maxshift - $thisshift); }
		$thisshift += $origlin->azimuth() - 180;
		my $wp = getPointAtDist($origlin->ox(),$origlin->oy(),$dist * $origlin->length(),$thisshift,1);
		$lastshift = $origlin->azimuth() - $wp->getMeta("azimuth");
		print " $i: $lastshift)\n";
		push(@points,$wp);
		$current += $p;
	}
