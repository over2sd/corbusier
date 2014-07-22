use strict;
use warnings;

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
	$mxj = floor($w / 8);
	my $myj = floor($h / 8);
	foreach my $i (0 .. $joins - 1) { # choose joining point(s)
		my ($d,$j,$x,$y) = 0,0,0,0;
		my $v = Vertex->new($i);
		my $success = Points::placePoint($v,2 * $mxj,3 * $mxj,2 * $myj,3 * $myj,\@sqs,(min($w,$h) > 125 ? 20 : 5),$joins * 10);
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
# If more than one highway per join, grow highways with weight toward even spacing around the map:
	print "\nPlacing highways..";
	if ($divisor >= $hiw) {
		print "Function incomplete!\n";
	} else { # not ($divisor >= $hiw)
# If fewer than one highway per join, just grow a highway from each to the nearest edge:
		my @exits;
		my @edges = ();
		foreach my $i (0 .. $#sqs) {
			# if more than two, ignore the one most central from list
			if ($i == $lowindex and $#sqs != 1) { print "'"; next; }
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
			my $e = Vertex->new();
			$e->move($x,$y);
			push(@exits,$e);
			my $line = Segment->new($numroutes);
			$line->set_ends($e->x(),$v->x(),$e->y(),$v->y());
			moveIfNear($line,-1,-1,100,@sqs);
			$numroutes += 1;
#	add highway to route list
			push(@rts,$line)
		}
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