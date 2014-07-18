use strict;

package MapDes;
use Points;
use Common;

use POSIX qw( floor );
use List::Util qw( min );
my $debug = 1;

sub genmap {
	if ($debug) { print "genmap(@_)\n"; }
	my ($hiw,$sec,$rat,$poi,$max,$w,$h) =  @_;
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	# later, put decision here about type(s) of map generation to use.
	# possibly, even divide the map into rectangular districts and use different methods to form each district's map?
	my ($numr,@rs) = branchmap($hiw,$sec,$rat,$poi,$max,$w,$h);
	if ($debug) { print "<=branchmap returned $numr routes to genmap\n"; }
	return $numr,@rs;
}

=item moveIfNear()
  This function takes a Segment, the index values of the origin and end of that Segment in the following array, a maximum distance, and an array of Vertex objects (of which two are expected to be the origin and endpoint of the Segment).
  It then checks to see if the line passes close (less than the maximum distance) to a point in the checklist, and if so, moves its endpoint to that point, expecting that that point will be connected at some time to the original endpoint.
  Returns whether the Segment was altered.
=cut

sub moveIfNear {
	my ($line,$origin_index,$end_index,$boundary,@checklist) = @_;
	# TODO: Sanity checks go here
	my $altered = 0;
	my $endpoint = $end_index;
	foreach my $j (0 .. $#checklist) {
		if ($j != $end_index and $j != $origin_index) {
			my $p = $checklist[$j];
			# check to see if line passes near a closer point:
			my $distance = Points::perpDist($p->x(),$p->y(),$line->ox(),$line->oy(),$line->ex(),$line->ey());
			if ($distance < $boundary) { # if another line ends close to this one, move our endpoint to that line's origin if the distance is shorter
				if ($line->length() > Points::getDist($line->ox(),$line->oy(),$p->x(),$p->y())) {
					print "~";
					$endpoint = $j;
				}
			}
		}
	}
	# This line is to finalize any alterations to the segment:
	if ($altered) { $line->move_endpoint($checklist[$endpoint]->x(),$checklist[$endpoint]->y()); }
	return $altered;
}

sub branchmap {
	if ($debug) { print "branchmap(@_)\n"; }
	my ($hiw,$sec,$rat,$poi,$max,$w,$h) =  @_;
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	my $numroutes = 0;
	my @sqs;
	my @rts;
	my @poi;
	my $mxj = $hiw > 20 ? 11 : $hiw > 10 ? 7 : 5;
	my $joins = floor(rand($mxj)) + 1; # choose number of intersections
	if ($debug) { print "  Joins: " . $joins . "/" . $mxj . "\n"; }
	$mxj = floor($w / 4);
	my $myj = floor($h / 4);
	foreach my $i (0 .. $joins - 1) { # choose joining point(s)
		my ($d,$j,$x,$y) = 0,0,0,0;
		my $v = Vertex->new($i);
		my $success = Points::placePoint($v,2 * $mxj,$mxj,2 * $myj,$myj,\@sqs,(min($w,$h) > 125 ? 20 : 5),$joins * 10);
		if ($v->x() != 0 and $v->y() != 0 and $success) {
		   push(@sqs,$v);
		} else {
			if ($debug) { print "!@%&"; }
		}
	}
	my @irts;
	my $lowindex = 0;
	# find point closest to center
	# later, add options to have "center" be closest to one corner, instead, or a random point instead of the most central.
	my @center = (floor($w / 2),floor($h / 2));
	$lowindex = Points::getClosest(@center,\@sqs);
	foreach my $i (0 .. $#sqs) {	 # link point to all other points
		if ($i != $lowindex) {
		   my $line = Segment->new($numroutes);
		   $numroutes += 1;
			# This line is to prepare for comparisons:
			$line->set_ends($sqs[$lowindex]->x(),$sqs[$i]->x(),$sqs[$lowindex]->y(),$sqs[$i]->y());
			moveIfNear($line,$i,$lowindex,20,@sqs);
			$line->immobilize();
#			  Save these highways to a separate list that will be added to the end of the routes, so other roads don't come off them.
		   push(@irts,$line)
		}
	}
# place highways

# count junctions
	my @joins;
	my $divisor = $#sqs;
	if ($divisor == 1) { # exactly two junctions
		$divisor++;
	}
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
	my @edges = ();
#	use Data::Dumper;
#	print Dumper @histogrow;
	foreach my $i (0 .. $#sqs) {
# if more than two, ignore the one most central from list
		if ($i == $lowindex and $#sqs != 1) { print "'"; next; }
		print ".";
# shift out a vertex and a number of highways to grow from it
		my $nh = shift @histogrow;
		my $v = $sqs[$i];
#		print ($v  or "undef") . " ";
# find closest compass direction
		my $exside = Points::closestCardinal($v->x(),$v->y(),$w,$h);
		if ($divisor < 4) { # for small number of junctions, don't let the exits cluster on one side.
			while (@edges and Common::findIn($exside,@edges) != -1) {
				$exside += 3; print ":";
				if ($exside > 7) { $exside -= 8; }
			}
#			print "Edge: $exside ";
		}
		push(@edges,$exside);
		while ($nh > 0) {
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
# (x (or y for E/W) +/- .25x)
##			my $base = ($xfirst ? $v->x() : $v->y());
			my $mate = $edge;
#			print "Edge: $base ";
#			$base = $base - floor($base / 4) + int(rand($base/2)) * ($xfirst ? $fx : $fy);
#			$base = $base - floor($base/4) + int(rand($rng)) * ($xfirst ? $fx : $fy);
			$base += int(rand($rng));
#			print "=> $base :: $edge\n";
# If total is greater than h (or w), trim, and push away from edge with excess
			if ($base > ($xfirst ? $w : $h)) {
				my $overage = $base - ($xfirst ? $w : $h) * ($xfirst ? $fy : $fx); # mate, so reverse order
				$mate += $overage;
				$base -= $overage;
			}
			($x,$y) = ($xfirst ? ($base,$mate) : ($mate,$base));
			if ($x > $w or $y > $h) {
				print "For " . $v->id() . ": ($x,$y) $exside\n";
			}
			foreach my $v (@exits) {
				my $mindist = int(($xfirst ? $w : $h) / 15);
				if (abs(($xfirst ? $v->x() - $x : $v->y() - $y)) < $mindist) {
					if ($debug > 8) { print "--nudge--(" . $v->x() . "," . $v->y() . ")><($x,$y)>>"; } else { print "^"; }
					my $mod;
					my $dist = ($xfirst ? $v->x() - $x : $v->y() - $y);
					($dist < 0 ? $mod = int(rand(4)) + $mindist - $dist : $mod = -int(rand(4)) -$mindist + $dist);
					if ($xfirst) { $x += $mod; }
					else { $y += $mod; }
					if ($x > $w) { $x = $w - 5; }
					if ($x < 0) { $x = int(rand(10)) + 5; }
					if ($y > $h) { $y = $h - 5; }
					if ($y < 0) { $y = int(rand(10)) + 5; }
					if ($debug > 8) { print "($x,$y)--"; }
# TODO: This function seriously needs improvement.
					if (abs(($xfirst ? $v->x() - $x : $v->y() - $y)) < $mindist) {
						print "Xnudge...(" . $v->x() . "," . $v->y() . ")>>";
						my $dist = ($xfirst ? $v->x() - $x : $v->y() - $y);
						($dist > 0 ? $mod = $mindist + 2 - $dist : $mod = -($mindist + 2) + $dist);
						($xfirst ? $v->x($v->x() + $dist) : $v->y($v->y() + $dist));
						print "(" . $v->x() . "," . $v->y() . ")...";
					}
				}
			}
			if ($debug > 1) { print "Edge pair for (" . $v->x() . "," . $v->y() . ") is now ($x,$y).\n"; }
			my $e = Vertex->new();
			$e->move($x,$y);
			push(@exits,$e);
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
#	add highway to route list
		push(@rts,$line)
	}
=for pseudo
place secondaries
	foreach highway:
		choose a point on highway
		choose a bearing coming off the highway
		choose a distance for the road to extend
		(check for bad juxtapositions?)
		add road to route list
place smaller roads
	checking for 
=cut
	push(@rts,@irts);
	return $numroutes,@rts;
}

1;