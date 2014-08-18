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
	sortsquares => 1,
	width => 800,
	height => 600,
	centerx => 400,
	centery => 300
);

sub genmap {
	if ($debug) { print "genmap(@_)\n"; }
	my ($hiw,$sec,$rat,$poi,$max,$centertype,$squareintersections) =  @_;
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	# later, put decision here about type(s) of map generation to use.
	# possibly, even divide the map into rectangular districts and use different methods to form each district's map?
	my ($numr,@rs) = branchmap($hiw,$sec,$rat,$max,$centertype,$squareintersections);
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
	my ($intersection,$road,$length,$pfactor,$bear,$doublechance) = @_;
#		choose a bearing coming off the highway
	my $minaz = ($pfactor == 3 ? 89 : ($pfactor == 2 ? 85 : ( $pfactor == 1 ? (rand(10) > 5 ? 60 : 80) : ($pfactor == -1 ? 0 : 40))));
	my $maxaz = ($pfactor == 3 ? 91 : ($pfactor == 2 ? 95 : ( $pfactor == 1 ? (rand(10) > 5 ? 100 : 120) : ($pfactor == -1 ? 1 : 140))));
	my $endpoint = Points::choosePointAtDist($intersection->x(),$intersection->y(),$length,$minaz,$maxaz,$bear);
#		Make sure the road doesn't go off the map
	my $w = $mdconfig{width};
	my $h = $mdconfig{height};
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
			my $w = $mdconfig{width};
			my $h = $mdconfig{height};
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
	my ($secondratio,$allperp,@bigroads) = @_;
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
			addSideHere($intersection,$sideroad,$len,($allperp ? 3 : (rand(8) > 7.0 ? 0 : 2)),$bear,75); # 100=chance of doubling?
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
	my ($ratio,@bigroads) = @_;
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
			my $foot = addSideHere($iv,$line,10 + rand($r->length()/6) + $r->length()/6,1,$r->azimuth(),95);
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
	my ($hiw,$sec,$rat,$max,$centertype,$forcesquare) =  @_;
	print "\n\n\n[E] This function has not yet been rewritten to use best available methods.\n\n\n";
	if (1) { exit(0); }

	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	my $numroutes = 0;
	my @sqs;
	my @rts;
	my $mxj = $hiw > 20 ? 11 : $hiw > 10 ? 7 : 5;
	my $joins = floor(rand($mxj)) + 1; # choose number of intersections
	if ($debug) { print "  Joins: " . $joins . "/" . $mxj . "\n"; }
	my $needed = 0;
	my @waypoints;
	my $unit = 0;
	my $divisor = $joins;
	if ($divisor < 2) { # fewer than three junctions
		$divisor++;
	}
# If more than one highway per join, grow highways with weight toward even spacing around the map:
	print "Dividing $hiw among $divisor junctions...";
# ensure enough junctions for highways to not look like a panicked exodus
	if ($divisor < ($hiw / 3)) {
		$needed = $hiw / 3 - $divisor;
	}
	@sqs = genSquares($joins,$centertype,0.75,\@waypoints,$needed,\$unit);
	# connect all village squares
	print "debug $numroutes ";
	my @irts = connectSqs(\@sqs,\@waypoints,$centertype,\$numroutes);
	my $lowindex = 0;
# place highways #############
	print "\nPlacing highways..";
	my @exits = castExits($hiw,\@waypoints,getCenter(),\$numroutes,0);
	my @orts = growHiw(\@exits,\@irts,\$numroutes);
	push(@rts,@orts);
#	place secondaries
	my @secondaries = branchSecondaries($sec,$forcesquare,@orts);
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
} ## endsub branchmap()


# centertype: 0 - central hub, 1 - starry ring (each point connects to one waypoint, which connects to the next central point), 2 - ring (each point connects to next point by azimuth), 3 - 2 or 3 central points, (good for river towns?)
sub genSquares {
	if ($debug > 1) { print "genSquares(@_)\n" };
	my ($qty,$centertype,$variance,$waypointsref,$wpqty,$unitref) = @_;
	unless ($qty) { return (); }
	my $width = $mdconfig{width};
	my $height = $mdconfig{height};
	my ($unit,$azunit,$cx,$cy,$centaz) = (min($width,$height)/12,360/(($qty*2) or 1),int($width/2+0.5),int(0.5+$height/2),int(rand(180)));
	$$unitref = $unit; # store unit for caller
	# Possible switch: offset all positions by +/- 1 * $unit?
	my ($centqty,@squares);
	if ($centertype == 1 or $centertype == 2) { $centqty = 0;
	} elsif ($centertype == 3) { $centqty = ($qty % 2 ? 2 : 3);
	} else {
		$centqty = 1;
	}
	foreach my $i (0 .. $centqty) {
		unless ($centqty) { last; }
		my $base = 120 * $i;
		my $p = Points::choosePointAtDist($cx,$cy,$unit/2,$base,$base+60,$centaz,1);
		push(@squares,$p);
		if (@squares >= $qty) { last; }
	}
	my $remainingsquares = $qty - @squares;
	print "Done: " . @squares . " Remaining: $remainingsquares...\n";
	my $base = (@squares ? rand($#squares * $azunit) : rand(3) * $azunit);
	while ($remainingsquares > 0) {
# centertype: 0 - central hub, 1 - starry ring (each point connects to one waypoint, which connects to the next central point), 2 - ring (each point connects to next point by azimuth)
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
#				my $az = Points::getAzimuth($cx,$cy,$s->x(),$s->y(),1);
				push(@sazs,$s->getMeta("azimuth"));
#				$s->setMeta("azimuth",$az);
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
				print " n $min x $max r $range \n" if ($debug > 8);
				push(@mins,$min);
				push(@ranges,$range);
				push(@counts,$thistime);
			}
			foreach my $i (0 .. $#counts) {
				my $min = $mins[$i];
				my $range = $ranges[$i];
				my $max = $min + ($range * $counts[$i]);
				print "Placing $counts[$i] waypoints between $min and $max...\n" if ($debug > 3);
				foreach my $j (0 .. $counts[$i] - 1) {
#					if ($wpqty <= @$waypointsref) { last; }
#					print "Round: $i:$j...\n";
### TODO: if making a starry ring center and #waypoints=#squares, set base and range narrowly, halfway between azimuths?
					my $base = $min + ($range * $j);
					my $dist = ($unit * 1.5) + ($centertype == 1 or $centertype == 2 ? rand(10) : rand($unit * $variance));
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
	my ($sqref,$wpref,$centertype,$numroutes) = @_;
	print "Linking village squares..";
	if ($debug > 1) { print "connectSqs(@_)\n"; }
	my @roads;
	# find point closest to center
	# later, add options to have "center" be closest to one corner, instead, or a random point instead of the most central.
#	my @center = (floor($w / 2),floor($h / 2));
	my @sqs = @$sqref;
	for ($centertype) {
		if (/2/) {
			my $here = $$sqref[0];
			foreach my $i (1 .. $#$sqref) {
				my $next = $$sqref[$i];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($here->x(),$next->x(),$here->y(),$next->y());
				print "Forming ring line " . $line->describe(1) . "\n";
				$line->immobilize();
				push(@roads,$line);
				$here = $next;
			}
			if ($#$sqref) {
				my $next = $$sqref[0];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($here->x(),$next->x(),$here->y(),$next->y());
				print "Forming ring line " . $line->describe(1) . "\n";
				$line->immobilize();
				push(@roads,$line);
			}
		} elsif (/1/) {
			if ($debug) { print "Starry ring doesn't connect its squares. This is working properly.\n"; }
		} elsif (/0/) {
			my $lowindex = Points::getClosest(getCenter(),$sqref);
			@sqs = squareSort(0,$sqs[$lowindex],@sqs);
			$lowindex = 0; # should be, after the previous line.
			foreach my $i (1 .. $#sqs) {	 # link point to all other points
				if ($i != $lowindex) {
					my $line = linkNearest($$numroutes,$sqs[$i],sprintf("Road%d",$i),0.67,25,@sqs[0 .. $i-1]);
					$line->immobilize();
					push(@roads,$line);
					$$numroutes++;
				}
			}
		} else { # centertype 0 or unkown...
	## connectSqs random mode?
			# find point closest to center
			# center now comes from argument, not this calculation
#			my @center = (floor($w / 2),floor($h / 2));
			my $lowindex = Points::getClosest(getCenter(),\@sqs);
			foreach my $i (0 .. $#sqs) {	 # link point to all other points
				if ($i != $lowindex) {
					my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
					# This line is to prepare for comparisons:
					$line->set_ends($sqs[$i]->x(),$sqs[$lowindex]->x(),$sqs[$i]->y(),$sqs[$lowindex]->y());
					moveIfNear($line,$i,$lowindex,20,@sqs);
					undoIfIsolated($line,\@roads,$sqs[$lowindex]->x(),$sqs[$lowindex]->y());
					$line->immobilize();
	#			  Save these highways to a separate list that will be added to the end of the routes, so other roads don't come off them.
					push(@roads,$line);
				}
#				if ($i == $#sqs and $numroutes < $hiw) { $i = 0; } elsif ($numroutes >= $hiw) { last; } #Another go around, or leave early
			}
		## end section
		}
	} # end of squares connections
	print ", waypoints..";
	
	for ($centertype) {
		if (/2/) {
			my @srindex;
			foreach (@$sqref) {
				push(@srindex,$_->getMeta("azimuth"));
			}
			my ($sorteda,$index) = listSort(\@srindex,@$sqref);
			foreach (@$wpref) {
				my $i = Common::findClosest($_->getMeta("azimuth"),@$index);
				my $j = $$sorteda[$i];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($_->x(),$j->x(),$_->y(),$j->y());
				$line->immobilize();
				push(@roads,$line);
			}
		} elsif (/1/) {
			my (@ring,@srindex);
			foreach (@$sqref) {
				push(@srindex,$_->getMeta("azimuth"));
				push(@ring,$_);
			}
			foreach (@$wpref) {
				push(@srindex,$_->getMeta("azimuth"));
				push(@ring,$_);
			}
			my ($sorteda,$index) = listSort(\@srindex,@ring);
			my $here = $$sorteda[0];
			foreach my $i (1 .. $#$sorteda) {
				my $next = $$sorteda[$i];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($here->x(),$next->x(),$here->y(),$next->y());
				$line->immobilize();
				push(@roads,$line);
				$here = $next;
			}
			if ($#$sorteda) {
				my $next = $$sorteda[0];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($here->x(),$next->x(),$here->y(),$next->y());
				$line->immobilize();
				push(@roads,$line);
			}
		} elsif (/0/) {
			foreach my $w (@$wpref) {
				print ".";
				my $lowindex = Points::getClosest($w->x(),$w->y(),$sqref);
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($w->x(),$$sqref[$lowindex]->x(),$w->y(),$$sqref[$lowindex]->y());
				$line->immobilize();
				push(@roads,$line);
			}
		} else { # centertype unkown...
			foreach my $vi (0 .. $#$wpref) { # connect new waypoints to old junctions
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				my $closest = Points::getClosest($$wpref[$vi]->x(),$$wpref[$vi]->y(),$sqref);
				my $w = $mdconfig{width};
				my $h = $mdconfig{height};
				$$wpref[$vi]->clip(0,0,$w,$h);
				$line->set_ends($$wpref[$vi]->x(),$$sqref[$closest]->x(),$$wpref[$vi]->y(),$$sqref[$closest]->y());
				$line->immobilize();
				push(@roads,$line);
			}
		}
	}
	print "\nConnected " . @$sqref . " squares with " . @roads . " inner routes...\n";
	return @roads;
}

sub squareSort {
	my ($returnindex,$origin,@a) = @_;
	my $i = ();
	foreach (@a) {
		push(@$i,Points::getDist($origin->x(),$origin->y(),$_->x(),$_->y()));
	}
	my ($sorteda,$index) = listSort($i,@a);
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
			if (@$lind) { push(@oi,shift(@$lind)); }
		} elsif (@$right) {
			push(@oa,shift(@$right));
			if (@$rind) { push(@oi,shift(@$rind)); }
		}
	}
	return \@oa,\@oi;
}

sub linkNearest {
	my ($idnum,$here,$name,$fraction,$pbound,@sortedlist) = @_;
	my $lisv = (ref($sortedlist[0]) eq "Vertex");
	my $line = Segment->new($idnum);
	$line->name($name);
	my ($x,$y) = (($lisv ? $sortedlist[0]->x() : $sortedlist[0]->ox()),($lisv ? $sortedlist[0]->y() : $sortedlist[0]->oy()));
	$line->set_ends($here->x(),$x,$here->y(),$y);
	if ($debug > 1) { print "Running " . $here->id() . ":\n"; } else { print "."; }
	my $lowdist = $line->length();
	foreach my $i (1 .. $#sortedlist) { # start at 1 because we just found the distance to 0.
		($x,$y) = (($lisv ? $sortedlist[$i]->x() : $sortedlist[$i]->ox()),($lisv ? $sortedlist[$i]->y() : $sortedlist[$i]->oy()));
		my $testdist = Points::getDist($line->ox(),$line->oy(),$x,$y,0);
		if ($testdist < $lowdist * $fraction and $testdist > 1) { # prevent excessive moves, and moves of end to origin.
			my $dist = Points::perpDist($x,$y,$line->ox(),$line->oy(),$line->ex(),$line->ey());
			if ($dist < $pbound) {
				print "Moving endpoint from (" . $line->ex() . "," . $line->ey() . ") to (" . $sortedlist[$i]->x() . "," . $sortedlist[$i]->y() . ").\n" if ($debug > 3);
				$line->move_endpoint($x,$y);
				$lowdist = $line->length();
			} else { 
				print "Perpdist: $dist (line not moved)\n" if ($debug > 3);
			}
		} else {
			printf("Test: %.2f vs %.2f\n",$testdist,$lowdist * $fraction) if ($debug > 3);
		}
	}
	return $line;
}

sub connectWaypoints {
	my ($sqref,$wpref,$contype) = @_;
	my @roads;

	return @roads;
}

sub setMDConf {
	my $changes = 0;
	my $spin = 0;
	while (@_ and $spin < 10) {
		my $key = shift;
		my $value = shift;
		$spin++;
		unless (defined $value) { return $changes; }
		$mdconfig{$key} = $value;
#		print "k: $key v: $mdconfig{$key} ... ";
	}
	return $changes;
}

sub getMDConf {
	my $key = shift;
	print "Seeking $key...";
	return $mdconfig{$key};
}

sub getCenter {
	my $x = $mdconfig{centerx};
	my $y = $mdconfig{centery};
#	print "..Center: ($x,$y)..";
	return $x,$y;
}

sub castExits {
	my ($qty,$road_aref,$origin_aref,$numroutes,$method) = @_;
	print "Attempting to cast $qty exits...";
	my @center = @$origin_aref;
	my @roads = @$road_aref;
	my @exits;
	my $w = $mdconfig{width};
	my $h = $mdconfig{height};
	for ($method) {
	 if (/0/) {
		my (@exazs,@wpazs);
		@wpazs = Points::getAzimuths(@center,\@roads);
		if ($qty <= scalar @roads) {
			my $offset = rand(30) - 15;
			foreach (@wpazs) {
				push(@exazs,$_ + $offset) if (scalar @exazs < $qty);
			}
		} else {
### Brilliant algorithm for distributing exits randomly with gravity toward azimuths of waypoints added goes here.
		}
		foreach (@exazs) {
			my $ev = Points::interceptFromAz($_,$w,$h); # running from center
			$ev->clip(0,0,$w,$h);
			$ev->setMeta("azimuth",Points::getAzimuth($w/2,$h/2,$ev->x(),$ev->y()));
			push(@exits,$ev);
		}
	 } else {
		if (@roads < $qty) {
			my $bearingrange = 360 / $qty;
			my $bearingbase = 0;
			while (scalar @exits < $qty) {
				my $bearing = $bearingbase + rand($bearingrange);
				my $ev = Points::interceptFromAz($bearing,$w,$h); # running from center
				$ev->clip(0,0,$w,$h);
				$ev->setMeta("azimuth",Points::getAzimuth($w/2,$h/2,$ev->x(),$ev->y()));
				push(@exits,$ev);
				$bearingbase += $bearingrange;
			}
		} else { # not ($divisor >= $hiw)
# If fewer than one highway per join, just grow a highway from each to the nearest edge:
			my @pexits;
			my @edges = ();
			my $w = $mdconfig{width};
			my $h = $mdconfig{height};
			foreach my $i (0 .. $#roads) {
				# if more than two, ignore the one most central from list
				print ".";
				my $r = $roads[$i];
#		print ($v  or "undef") . " ";
# find closest compass direction
				my $exside = Points::closestCardinal($r->ox(),$r->oy(),$w,$h);
				if (@roads < 4) { # for small number of junctions, don't let the exits cluster on one side.
					while (@edges and Common::findIn($exside,@edges) != -1) {
						$exside += 1; print ":";
						if ($exside > 7) { $exside -= 8; }
					}
					push(@edges,$exside);
				}
				my ($fx,$fy,$xfirst,$edge) = (1,1,1,0);
				if ($debug > 1) { print "Highway $qty is exiting: $exside... \n"; }
				$qty--;
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
					print "For " . $r->id() . ": ($x,$y) $exside\n";
				}
# If total is greater than h (or w), trim, and push away from edge with excess
				foreach my $ev (@pexits) {
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
				$e->setMeta("azimuth",Points::getAzimuth($w/2,$h/2,$e->loc()));
				push(@pexits,$e);
				unless ($qty) { last; }
			}
			push (@exits,@pexits);
			print ":$qty=-=" . scalar @exits . ":";
			unless ($qty) { last; }
		}
	 }
	}
	print "Returning " . scalar @exits . " exits...\n";
	return @exits;
}

sub growHiw {
	my ($exits,$roads,$numroutes) = @_;
	my @hiw;
	foreach my $ev (@$exits) {
#		highways will go from exit to closest join
		my $line = linkNearest($$numroutes++,$ev,sprintf("Road on %.2f",$ev->getMeta("azimuth")),1.0,100,@$roads);
		if ($debug > 1) { print "\t" . $line->describe(1) . "\n"; }
		push(@hiw,$line);
	}
	return @hiw
}

1;