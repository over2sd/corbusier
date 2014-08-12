use strict;
use warnings;

package MapDes;
use Points;
use Common;

use POSIX qw( floor );
use List::Util qw( min );
my $debug = 1;
my %mdconfig = (
	errorsarefatal => 0,
	sortsquares => 1
);

sub genmap {
	if ($debug) { print "genmap(@_)\n"; }
	my ($hiw,$sec,$rat,$poi,$max,$w,$h,$squareintersections) =  @_;
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	# later, put decision here about type(s) of map generation to use.
	# possibly, even divide the map into rectangular districts and use different methods to form each district's map?
	my ($numr,@rs) = branchmap($hiw,$sec,$rat,$max,$w,$h,$squareintersections);
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
	if ($debug > 1) { print "Comparing length " . sprintf("%.2f",$line->length()) . " to points... "; }
	foreach my $j (0 .. $#checklist) {
		if ($j != $end_index and $j != $origin_index) {
			my $p = $checklist[$j];
			# check to see if line passes near a closer point:
			my $distance = Points::perpDist($p->x(),$p->y(),$line->ox(),$line->oy(),$line->ex(),$line->ey());
			if ($distance < $boundary) { # if another line ends close to this one, move our endpoint to that line's origin if the distance is shorter
#				my $q = Points::getDist($line->ox(),$line->oy(),$p->x(),$p->y());
				# point's distance from central point
				my $q = Points::getDist($checklist[$origin_index]->x(),$checklist[$origin_index]->y(),$p->x(),$p->y());
				# line-end's distance from central point
				my $r = Points::getDist($line->ox(),$line->oy(),$checklist[$origin_index]->x(),$checklist[$origin_index]->y());
				if ($q and $r > $q) {
					if ($debug > 2) { print "Moving " . $line->ex() . "," . $line->ey() . " to " . $p->x() . "," . $p->y() . "\n"; } else { print "~"; }
					$endpoint = $j;
					$altered = 1;
				} elsif ($debug > 2) {
					printf(" %i,%i :%.2f; ",$p->x(),$p->y(),$q);
				}
			} elsif ($debug > 2) {
				printf(" %d,%d - Distance: %.2f; ",$p->x(),$p->y(),$distance);
			}
		}
	}
	# This line is to finalize any alterations to the segment:
	if ($altered) { $line->move_endpoint($checklist[$endpoint]->x(),$checklist[$endpoint]->y()); }
	return $altered;
}

=item undoIfIsolated()
	Returns the line's endpoint to the given original x,y if the line is the reverse of a line in the given list
=cut
sub undoIfIsolated {
	my ($seg,$lref,$ox,$oy) = @_;
	my @segments = @$lref;
	my $iamtwinned = 0;
	foreach my $twin (@segments) {
		if ($seg->ex() == $twin->ox()) {
			if ($seg->ey() == $twin->oy()) {
				if ($seg->ox() == $twin->ex()) {
					if ($seg->oy() == $twin->ey()) {
						$iamtwinned = 1;
					}
				}
			}
		} elsif ($seg->ex() == $twin->ex()) {
			if ($seg->ey() == $twin->ey()) {
				if ($seg->ox() == $twin->ox()) {
					if ($seg->oy() == $twin->oy()) {
						$iamtwinned = 1;
					}
				}
			}
		} elsif ($seg->ox() == $twin->ex()) {
			if ($seg->oy() == $twin->ey()) {
				if ($seg->ex() == $twin->ox()) {
					if ($seg->ey() == $twin->oy()) {
						$iamtwinned = 1;
					}
				}
			}
		} elsif ($seg->ox() == $twin->ox()) {
			if ($seg->oy() == $twin->oy()) {
				if ($seg->ex() == $twin->ex()) {
					if ($seg->ey() == $twin->ey()) {
						$iamtwinned = 1;
					}
				}
			}
		}
	}
	if ($iamtwinned) {
		$seg->move_endpoint($ox,$oy); # back to what the line once was.
		print "@";
		return 1;
	}
	return 0;
}

my @dist = (0,0,0);
sub getDistribution { return @dist; }
=item addSideHere()

=cut
sub addSideHere {
	my ($intersection,$road,$length,$pfactor,$bear,$w,$h,$doublechance) = @_;
#		choose a bearing coming off the highway
	my $minaz = ($pfactor == 3 ? 89 : ($pfactor == 2 ? 85 : ( $pfactor == 1 ? (rand(10) > 5 ? 60 : 80) : ($pfactor == -1 ? 0 : 40))));
	my $maxaz = ($pfactor == 3 ? 91 : ($pfactor == 2 ? 95 : ( $pfactor == 1 ? (rand(10) > 5 ? 100 : 120) : ($pfactor == -1 ? 1 : 140))));
	my $endpoint = Points::choosePointAtDist($intersection->x(),$intersection->y(),$length,$minaz,$maxaz,$bear);
#		Make sure the road doesn't go off the map
	$endpoint->clip(0,0,$w,$h);
#		Draw a line between the point and the line
	$road->set_ends(int($endpoint->x()),int($intersection->x()),int($endpoint->y()),int($intersection->y()));
#		Extend the road an equal distance past the intersection some percentage of the time
	my $roaddoubling = 0;
	my $secondroad = undef;
	if ($doublechance >= 100 or rand(100) < $doublechance) {
		my $a = $road->azimuth() - $bear;
		if ($a < 180 and $a > 135) {
			$roaddoubling = 2;
		} elsif ($a < 360 and $a > 315) {
			$roaddoubling = 3;
		} else {
			$roaddoubling = 1;
			$road->double($w,$h);
		}
		$road->roundLoc(0);
	}
	return $secondroad;
}

=item adjustSideRoad()
	Moves segment ends if they are less than boundary from endpoints of lines in the given list. Once both ends have been moved, it returns.
=cut
sub adjustSideRoad {
	if ($debug > 1) { print "adjustSideRoad(@_)\n"; }
	my ($sideroad,$boundary,@smallroads) = @_;
	my ($startmoved,$endmoved) = (0,0);
	foreach my $r (@smallroads) {
		my ($x,$y,$v,$w) = ($r->ox(),$r->oy(),$r->ex(),$r->ey());
		my $a = Points::getDist($sideroad->ox(),$sideroad->oy(),$x,$y);
		my $b = Points::getDist($sideroad->ox(),$sideroad->oy(),$v,$w);
		my $c = Points::getDist($sideroad->ex(),$sideroad->ey(),$x,$y);
		my $d = Points::getDist($sideroad->ex(),$sideroad->ey(),$v,$w);
		if ($a < $boundary) {
			$sideroad->move($x,$y);
			$startmoved = 1;
		} elsif ($b < $boundary) {
			$sideroad->move($v,$w);
			$startmoved = 1;
		}
		if ($c < $boundary) {
			$sideroad->move_endpoint($x,$y);
			$endmoved = 1;
		} elsif ($d < $boundary) {
			$sideroad->move_endpoint($v,$w);
			$endmoved = 1;
		}
		if ($startmoved and $endmoved) { last; }
	}
	return $startmoved + $endmoved;
}

=item branchSecondaries()
	Makes a number of secondary roads on a list of highways, then tries to connect some of them together.
=cut
sub branchSecondaries {
	if ($debug) { print "branchSecondaries(@_);"; }
	my ($secondratio,$w,$h,$allperp,@bigroads) = @_;
	my @smallroads;
	foreach my $r (@bigroads) {
#	foreach highway:
		my $sidestomake = int(0.5 + rand($secondratio));
		my $posrange = 1/($sidestomake + 2);
		foreach my $i (0 .. $sidestomake) {
			my $id = scalar(@bigroads)+scalar(@smallroads);
			my $bear = $r->azimuth();
			if ($id % 2) { $bear += int(rand(10) + 175); }
			my $sideroad = Segment->new($id,sprintf("%.2f Road %d",$bear,$id));
#		choose a point on highway
			my $intersection = Points::findOnLine($r->ex(),$r->ey(),$r->ox(),$r->oy(),(($posrange/3)+rand($posrange)+($posrange*$i)));
#		choose a distance for the road to extend
			my $len = int((rand($r->length()/6)+$r->length()/6)+10);
			addSideHere($intersection,$sideroad,$len,($allperp ? 3 : (rand(8) > 7.0 ? 0 : 2)),$bear,$w,$h,75); # 100=chance of doubling?
#		(check for bad juxtapositions?)
			adjustSideRoad($sideroad,20,@smallroads);
#		add road to route list
			push(@smallroads,$sideroad);
		}
	}
	return @smallroads;
}

sub branchSides {
	if ($debug) { print "branchSides(@_);"; }
	my ($ratio,$width,$height,@bigroads) = @_;
	my @sideroads;
# for each road
	my $pos = 0.5;
	foreach my $r (@bigroads) {
# range is 1/(ratio*2), because we'll be putting a range between each range for roads, to keep the roads far enough apart
		my $range = 1/(($ratio or 1) * 2);
		foreach my $i (0 .. $ratio - 1) {
# every other road will be below 0.5, then above 0.5
			if ($i % 2) {
				$pos = 0.5 + ($range * $i);
			} else {
				$pos = 0.5 - ($range * $i) - $range; # so the even ones are at the same distance as the odd ones from the center
			}
# check for over 1/under 0
			if ($pos > 1.0) {
				$pos -= 1.0;
			} elsif ($pos < 0.0) {
				$pos += 1.0;
			}
# pick position
			my $fraction = $pos + (rand($range) * ($i % 2 ? 1 : -1));
			if ($fraction >= 1.0 or $fraction <= -1.0) { # this doesn't solve the problem I hoped it would... TODO: find source of problem and fix it
				printf("branchSides() has escaped its bounds ($fraction/1.0) on round $i/$ratio from position %.4f in range %.4f of the following line:",$pos,$range);
				print $r->describe(1) . "\n";
				exit(-9);
			}
			my $iv = Points::findOnLine($r->ox(),$r->oy(),$r->ex(),$r->ey(),$fraction);
			$iv->roundLoc(0);
	############ Test!!!
			my $line = Segment->new(0,"test $i");
# pick length of road
# pick distance from parent to start road
# place road
			my $foot = addSideHere($iv,$line,10 + rand($r->length()/6) + $r->length()/6,1,$r->azimuth(),$width,$height,95);
			if (defined $foot) {
				print $foot->describe(1) . "\n";
				push(@sideroads,$foot);
			}
# shorten/extend road if it crosses or almost reaches another road
			print $line->describe(1) . "\n";
			push(@sideroads,$line);
		}
	}
	return @sideroads;
}

sub branchmap {
	if ($debug) { print "branchmap(@_)\n"; }
	my ($hiw,$sec,$rat,$max,$w,$h,$forcesquare) =  @_;
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	my $numroutes = 0;
	my @sqs;
	my @rts;
	my @poi;
	my $mxj = $hiw > 20 ? 11 : $hiw > 10 ? 7 : 5;
	my $joins = floor(rand($mxj)) + 1; # choose number of intersections
	if ($debug) { print "  Joins: " . $joins . "/" . $mxj . "\n"; }


## genSqs random mode
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
	my @secondaries = branchSecondaries($sec,$w,$h,$forcesquare,@rts);
	$numroutes += scalar(@secondaries);
	push(@rts,@secondaries);
#place smaller roads
### This needs a new function...
	my @sideroads = branchSides($rat,$w,$h,@secondaries);
	$numroutes += scalar(@sideroads);
	push(@rts,@sideroads);
	# add in internal routes
	push(@rts,@irts);
	return $numroutes,@rts;
}

sub genSquares {
	print "genSquares(@_)\n";
	my ($qty,$width,$height,$grouptype,$variance,$waypointsref,$wpqty) = @_;
	unless ($qty) { return (); }
	my ($unit,$azunit,$cx,$cy,$centaz) = (min($width,$height)/12,360/(($qty*2) or 1),int($width/2+0.5),int(0.5+$height/2),int(rand(180)));
	# Possible switch: offset all positions by +/- 1 * $unit?
	my ($centqty,@squares);
	if ($grouptype == 1) { $centqty = 0;
	} elsif ($grouptype == 2) { $centqty = ($qty % 2 ? 2 : 3);
	} else {
		$centqty = 1;
	}
	foreach my $i (0 .. $centqty) {
		my $base = 120 * $i;
		my $p = Points::choosePointAtDist($cx,$cy,$unit/2,$base,$base+60,$centaz,1);
		push(@squares,$p);
		if (@squares >= $qty) { last; }
	}
	my $remainingsquares = $qty - @squares;
	print "Done: " . @squares . " Remaining: $remainingsquares...\n";
	my $base = rand($#squares * $azunit);
	while ($remainingsquares > 0) {
		my $p = Points::choosePointAtDist($cx,$cy,$unit,$base,$base+$azunit,0,1);
		$base += $azunit * 2;
		push(@squares,$p);
		$remainingsquares--;
	}
	print "I've made " . @squares . "/$qty squares.\n";
	if ($wpqty) {
		if (ref($waypointsref) eq "ARRAY") {
			my @sazs;
			foreach my $s (@squares) {
				my $az = Points::getAzimuth($cx,$cy,$s->x(),$s->y(),1);
				push(@sazs,$az);
			}
			@sazs = sort { $a <=> $b } @sazs;
			my $wpeach = $wpqty / @sazs;
			my $extra = ($wpqty - int($wpeach) * @sazs);
			print "Each square gets " . int($wpeach) . " waypoints with " . $extra  . " remaining.\n";
			my (@mins,@counts,@ranges);
			foreach my $i (0 .. $#sazs) {
				# TODO? -- Make the waypoints cluster near the squares by using min/max(current algo,square azimuth +/- 10)? Would this cause problems with many waypoints?
				my $min = ($i ? ($sazs[$i-1] + $sazs[$i])/2 + 1 : 0); # midpoint between this and prev, or 0
				my $max = ($i != $#sazs ? ($sazs[$i] + $sazs[$i+1])/2 - 1 : 359); # midpoint between this and next, or 359
				my $thistime = int($wpeach) + ($extra ? 1 : 0);
				$extra -= ($extra ? 1 : 0);
				my $range = ($max - $min) / ($thistime);
				unless ($range > 1) { $range = 1; }
				print " n $min x $max r $range \n";
				push(@mins,$min);
				push(@ranges,$range);
				push(@counts,$thistime);
			}
			foreach my $i (0 .. $#counts) {
				my $min = $mins[$i];
				my $range = $ranges[$i];
				my $max = $min + ($range * $counts[$i]);
				print "Placing $counts[$i] waypoints between $min and $max...\n";
				foreach my $j (0 .. $counts[$i] - 1) {
#					if ($wpqty <= @$waypointsref) { last; }
#					print "Round: $i:$j...\n";
					my $base = $min + ($range * $j);
					my $dist = ($unit * 1.5) + rand($unit * 0.75);
#					print "Placing at " . sprintf("%.2f",$dist) . " along azimuth between $base and " . ($base + $range) . "...\n";
					my $wp = Points::choosePointAtDist($cx,$cy,$dist,$base,$range + $base,0,1);
					push (@$waypointsref,$wp);
				}
			}
			print "I've added " . @$waypointsref . "/$wpqty waypoints.\n";
		} else {
			print "  [W] $waypointsref is not an array reference! Cannot add waypoints!\n";
			if ($mdconfig{errorsarefatal}) { exit(-5); }
		}
	}
	return @squares;
}

# centertype: 0 - central hub, 1 - starry ring (each point connects to one waypoint, which connects to the next central point), 2 - ring (each point connects to next point by azimuth)

sub connectSqs {
	my ($sqref,$wpref,$centertype,@center) = @_;
	my @roads;
	my $numroutes = 1;
	# find point closest to center
	# later, add options to have "center" be closest to one corner, instead, or a random point instead of the most central.
#	my @center = (floor($w / 2),floor($h / 2));
	my $lowindex = Points::getClosest(@center,$sqref);
	my @sqs = @$sqref;
	@sqs = squareSort(0,$sqs[$lowindex],@sqs);
	foreach my $i (0 .. $#sqs) {	 # link point to all other points
		if ($i != $lowindex) {
		   my $line = Segment->new($numroutes);
		   $numroutes += 1;
			# This line is to prepare for comparisons:
			$line->set_ends($sqs[$i]->x(),$sqs[$lowindex]->x(),$sqs[$i]->y(),$sqs[$lowindex]->y());
			$line->name(sprintf("Road%d",$i));
			moveIfNear($line,$i,$lowindex,20,@sqs);
			undoIfIsolated($line,\@roads,$sqs[$lowindex]->x(),$sqs[$lowindex]->y());
			$line->immobilize();
		   push(@roads,$line)
		}
#		if ($i == $#sqs and $numroutes < $hiw) { $i = 0; } elsif ($numroutes >= $hiw) { last; } #Another go around, or leave early
	}
	return $numroutes,@roads;
}

sub squareSort {
	my ($returnindex,$origin,@a) = @_;
	my $i = ();
	foreach (@a) {
		push(@$i,Points::getDist($origin->x(),$origin->y(),$_->x(),$_->y()));
	}
	my ($sorteda,$index) = listSort($i,@a);
	use Data::Dumper;
	print Dumper @$sorteda;
	print Dumper @$index;
	exit(0);
	if ($returnindex) { return @$index; }
	else { return @$sorteda; }
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
			if (@$lind) { push(@oi,@$lind); }
		} elsif (@$right) {
			push(@oa,shift(@$right));
			if (@$rind) { push(@oi,@$rind); }
		}
	}
	return \@oa,\@oi;
}

1;