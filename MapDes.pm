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
my $termcolors = 0;
my $basecolor = "";
my $funcolor = "";

sub enableTermcolors {
	my ($colname) = (shift or "ltblue");
	$termcolors = 1;
	$basecolor = Common::getColorsbyName("base");
	$funcolor = Common::getColorsbyName($colname);
}

sub genmap {
    if ($debug > 0) { print $funcolor . "genmap(" . ($debug > 7 ? "$basecolor@_$funcolor" : "") . ")$basecolor\n"; }
	my ($hiw,$sec,$rat,$poi,$max,$centertype,$squareintersections) =  @_;
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	# later, put decision here about type(s) of map generation to use.
	# possibly, even divide the map into rectangular districts and use different methods to form each district's map?
	my ($numr,@rs) = branchmap($hiw,$sec,$rat,$max,$centertype,$squareintersections);

	my $size = scalar @rs;
	if (0) { print "Checking for duplicate routes..."; }
	@rs = Points::seg_remove_dup(\@rs,0); # trim out duplicate segments to make drawing more efficient
	if (0) { print "Removed " . ($size - scalar @rs) . " duplicate route" . ($size - scalar @rs == 1 ? "" : "s") . ".\n"; }
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
die "Bad line" unless (defined $line);
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
	my ($secondratio,$allperp,$factor,@bigroads) = @_;
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
#			my $len = int((rand($r->length()/6)+$r->length()/6)+10) * ($factor or 1);
			my $len = (Points::getDist($intersection->loc(),getCenter(),1) + $r->length() * $factor) / 2;
			$len = int(rand($len) + 10);
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
		unless (ref($r) eq "Segment") { print "[E] Not a road (" . ref($r) . ")in branchSides()!"; exit(-4); }
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
	@sqs = genSquares($joins,$centertype,0.75,\@waypoints,$needed,\$unit,0.75); #1/12
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
	my @secondaries = branchSecondaries($sec,$forcesquare,1,@orts);
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
	if ($debug > 1) { $|++; print "genSquares(@_)\n" };
	my ($qty,$centertype,$variance,$waypointsref,$wpqty,$unitref,$scale) = @_;
	unless ($qty and defined $scale) { return (); }
	my $width = $mdconfig{width};
	my $height = $mdconfig{height};
	my ($unit,$azunit,$cx,$cy,$centaz) = (min($width,$height)/10,360/(($qty*2) or 1),getCenter(),int(rand(180)));
print "\nmy (unit,azunit,cx,cy,centaz) = ($unit,$azunit,$cx,$cy,$centaz);\n";
	$$unitref = $unit; # store unit for caller
	# Possible switch: offset all positions by +/- 1 * $unit?
	my ($centqty,@squares);
	if ($centertype == 1 or $centertype == 2) { $centqty = 0;
	} elsif ($centertype == 3) { $centqty = ($qty % 2 ? 2 : 3);
	} else { $centqty = 1;
	}
	foreach my $i (0 .. $centqty) {
		unless ($centqty) { last; }
		my $base = 120 * $i + rand(15);
		my $actualdist = $unit*(0.5 + rand(1))*$scale;
		my $p = Points::choosePointAtDist($cx,$cy,$actualdist,$base,$base+60,$centaz,1);
		push(@squares,$p);
		if (@squares >= $qty) { last; }
	}
	my $remainingsquares = $qty - @squares;
	print "Done: " . @squares . " Remaining: $remainingsquares...\n";
	my $base = (@squares ? rand(($#squares + 3) * $azunit) : rand(3) * $azunit);
	while ($remainingsquares > 0) {
# centertype: 0 - central hub, 1 - starry ring (each point connects to one waypoint, which connects to the next central point), 2 - ring (each point connects to next point by azimuth)
		my $actualdist = $unit * (1.55 + rand(1)) * $scale;
		my $p = Points::choosePointAtDist($cx,$cy,$actualdist,$base,$base+$azunit,0,1);
		$base += $azunit * (1+rand(3));
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
	my ($sqref,$wpref,$centertype,$numroutes,%exargs) = @_;
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
				$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
				print "Forming ring line " . $line->describe(1) . "\n";
				$line->immobilize();
				push(@roads,$line);
				$here = $next;
			}
			if ($#$sqref) {
				my $next = $$sqref[0];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($here->x(),$next->x(),$here->y(),$next->y());
				$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
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
					$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
#					$line->immobilize();
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
					$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
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
			my ($sorteda,$index) = Common::listSort(\@srindex,@$sqref);
			foreach (@$wpref) {
				my $i = Common::findClosest($_->getMeta("azimuth"),@$index);
				my $j = $$sorteda[$i];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($_->x(),$j->x(),$_->y(),$j->y());
				$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
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
			my ($sorteda,$index) = Common::listSort(\@srindex,@ring);
			my $here = $$sorteda[0];
			foreach my $i (1 .. $#$sorteda) {
				my $next = $$sorteda[$i];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($here->x(),$next->x(),$here->y(),$next->y());
				$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
				$line->immobilize();
				push(@roads,$line);
				$here = $next;
			}
			if ($#$sorteda) {
				my $next = $$sorteda[0];
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($here->x(),$next->x(),$here->y(),$next->y());
				$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
				$line->immobilize();
				push(@roads,$line);
			}
		} elsif (/0/) {
			foreach my $w (@$wpref) {
				print ".";
				my $lowindex = Points::getClosest($w->x(),$w->y(),$sqref);
				my $line = Segment->new($$numroutes,sprintf("Road%d",++$$numroutes));
				$line->set_ends($w->x(),$$sqref[$lowindex]->x(),$w->y(),$$sqref[$lowindex]->y());
				$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
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
				$line->setMeta('color',$exargs{color}) if (defined $exargs{color});
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
	my ($sorteda,$index) = Common::listSort($i,@a);
	if ($returnindex) { return @$index; }
	else { return @$sorteda; }
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

=item bendAtBoundBox()
	Takes a reference to a list of Segments and bends them when they cross the edges of the bounding box (described as minimi\um x, minimum y, maximum x, maximum y).
	Alters the Segments given so they end at the boundary box, if they cross.
	Warning: This function assumes a competent caller that passes the bounding box in the proper order, such that each maximum is greater than its minimum.
	It further assumes that the given list features segments that go from the outside to the inside.
	Returns a list of Segments representing the portion bent outside the box.
=cut
sub bendAtBoundBox {
	my ($ix,$iy,$ax,$ay,$list,$whole,$numroutes) = @_;
	my (@ext,@box);
	my $top = Segment->new(1,"Top",$ix,$ax,$iy,$iy);
	my $right = Segment->new(0,"Right",$ax,$ax,$iy,$ay);
	my $bottom = Segment->new(1,"Bottom",$ix,$ax,$ay,$ay);
	my $left = Segment->new(0,"Left",$ix,$ix,$iy,$ay);
	if ($ax-$ix > $ay-$iy) { # select order based on difference between box boundaries
		push(@box,$top,$bottom,$left,$right);
	} else {
		push(@box,$left,$right,$top,$bottom);
	}
	foreach (@$list) { # for each item in given list
		foreach my $b (@box) { # check against each
			if ($_->getMeta("bent")) { next; }
			my ($touches,$tx,$ty) = $_->touches($b);
			if ($whole) { $tx = nround(0,$tx); $ty = nround(0,$ty); }
			if ($touches) {
				my $x = ($b->id() ? ($_->ox() + $tx) / 2 : $_->ox());
				my $y = ($b->id() ? $_->oy() : ($_->oy() + $ty) / 2);
				if ($whole) { $x = nround(0,$x); $y = nround(0,$y); }
				my $line = Segment->new($$numroutes,sprintf("%s-alt",$_->name()));
				$line->set_ends($x,$tx,$y,$ty);
				push(@ext,$line);
				print "^";
				$_->move_origin_only($tx,$ty);
				$_->setMeta("bent",1);
			}
		}
	}
	return @ext
}

sub beltPreprocess {
	my ($href,@array) = @_;
	unless (ref($href) eq "HASH") { print "[E] beltPreprocess passed " . ref($href) . " instead of HASH."; unless ($mdconfig{errorsarefatal}) { return; } else { exit(-3); }}
	# TODO: sanity checking goes here
	foreach (0 .. $#array) {
		my $spoke = sprintf("t%02d",$_); # maximum 100 spokes before key behavior is unpredictable
		my $a = $array[$_];
		unless (ref($a) eq "Segment") { print "[E] beltPreprocess array position $_ is " . ref($a) . " instead of Segment."; unless ($mdconfig{errorsarefatal}) { return; } else { exit(-4); }}
		my $p = Vertex->new(0,"temporary",$a->origin(1));
		push(@{$$href{$spoke}},$p);
	}
}

sub tieredBelts {
	my ($ratio,$maxda,$numroutes,$twist,$sorted,@tier) = @_;
	my (@belt,@lines);
	print "$$numroutes ";
	unless ($sorted) {
		my $i = ();
		foreach (@tier) {
			$_->setMeta("azimuth",Points::getAzimuth(getCenter(),$_->x(),$_->y()));
			push(@$i,$_->getMeta("azimuth"));
		}
		my ($sorteda,$index) = Common::listSort($i,@tier);
		@tier = @$sorteda;
	}
	my $lastpoint = $tier[$#tier];
	my $lastaz = Points::getAzimuth(getCenter(),$tier[$#tier]->loc()) - 360; # make the subtraction simpler
	foreach (@tier) {
		my $thisaz = Points::getAzimuth(getCenter(),$_->loc());
		my $deltaaz = $thisaz - $lastaz;
		if ($deltaaz <= $maxda) {
			print "D";
			my ($v,$w,$x,$y) = ($lastpoint->loc(0),$_->describe(0));
			my $line = Segment->new($$numroutes,sprintf("Belt %d",++$$numroutes),$v,$x,$w,$y);
			push(@lines,$line);
		} elsif ($deltaaz < 2 * $maxda) {
			print "I";
			my $base = Points::getDist(getCenter(),$lastpoint->loc(),1);
			my $bound = Points::getDist(getCenter(),$_->loc(),1);
			my $dist = vary(($base + $bound) / 2,($maxda % 10) + 25);
			my $midbear = $lastaz + (($thisaz - $lastaz) / 2);
			my ($v,$w,$x,$y) = ($lastpoint->loc(),$_->loc());
			my $midpoint = Vertex->new(Points::useRUID(),"temporary",($v + $x)/2,($w + $y)/2);
			$midpoint->wobble($maxda/2);
			($v,$w,$x,$y) = ($midpoint->loc(),$lastpoint->loc());
			my $old = Segment->new($$numroutes,sprintf("Belt %da",$$numroutes++),$x,$v,$y,$w);
			($x,$y) = $_->loc();
			my $new = Segment->new($$numroutes,sprintf("Belt %db",$$numroutes++ - 1),$v,$x,$w,$y);
			push(@lines,$old,$new);
		} else {
			print "S";
			my $dist = abs(Points::getDist($_->loc(),$lastpoint->loc(),0) * 0.275);
			$dist = vary($dist,$dist / 2);
			my $end = Points::getPointAtDist($lastpoint->loc(),vary($dist,$dist / 2),vary($lastaz + 110,15),1);
			my ($v,$w,$x,$y) = ($end->loc(),$lastpoint->loc());
			my $line = Segment->new($$numroutes,sprintf("Belt %da",$$numroutes++),$x,$v,$y,$w);
			push(@lines,$line);
			$end = Points::getPointAtDist($_->loc(),$dist,vary($thisaz - 110,15),1);
			($v,$w,$x,$y) = ($_->loc(),$end->loc());
			$line = Segment->new($$numroutes,sprintf("Belt %db",$$numroutes++ - 1),$x,$v,$y,$w);
			push(@lines,$line);
		}
		$lastpoint = $_; $lastaz = $thisaz; # roll prevoiuses to currents
	}
	unless ($twist) { # already finished
		print "-:-";
		push(@belt,@lines);
	} else { # twist each line
		print "-+-";
		foreach (@lines) {
			my @temparray = Points::twist($_,$ratio);
			push(@belt,@temparray,$_);
		}
	}
	return @belt;
}

sub placePOI {
    if ($debug > 0) { print $funcolor . "placePOI(" . ($debug > 7 ? "$basecolor@_$funcolor" : "") . ")$basecolor\n"; }
	my ($mainsections,$secondaries,$sideratio,$poi,$maxroads) = @_;
	my $width = $mdconfig{width};
	my $height = $mdconfig{height};
	my ($unit) = (min($width,$height)/12);

}

sub genHexMap {
	my ($hiw,$sec,$rat,$poi,$maxr,$centyp,$force,$g,$screen) = @_;
	my ($nr,@routes) = (0,());
	if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
	my $mxj = ($hiw > 20 ? 11 : ($hiw > 10 ? 7 : 5));
	my $joins = ($force ? $force : floor(rand($mxj)) + 1); # choose number of intersections
	if ($debug) { print "  Joins: " . $joins . "/" . $mxj . "\n"; }
	my $needed = 0; # how many crossroads do we have to have?
	my @waypoints; # storage for added waypoints
	my $unit = 0; # genSquares will edit this
	my $divisor = $joins;
	($divisor < 2) && $divisor++; # fewer than three junctions
	# If more than one highway per join, grow highways with weight toward even spacing around the map:
	print "Dividing $hiw among $divisor($joins) junctions...";
	# ensure enough junctions for highways to not look like a panicked exodus
	($divisor < ($hiw / 3)) && ($needed = $hiw / 3 - $divisor);
	# choose squares
	my @squares = genSquares($joins,$centyp,0.75,\@waypoints,$needed,\$unit,1.1);
print "Received " . scalar @squares . " squares...";
	foreach (@squares) {
		my ($cx,$cy) = $screen->offset();
		my $color = MapDraw::incColor();
		drawPOI($_,{r => int($screen->sx / 4), f => $color,xoff => $cx, yoff => $cy});
		drawHexAt($screen,$_); # TODO: remove from final version
	}
	# connect all village squares
	print "debug $nr ";
	my @irts = connectSqs(\@squares,\@waypoints,$centyp,\$nr);
	@irts = connectSqsHex($screen,\@irts,$g); #,color => $color);
	push(@routes,@irts);
	# center squares in hexes
	my @border = $g->genborder(); # get possible exits
	# choose exits
	my @exits = pickExitHexes($hiw,$screen,$g,@border);
	# find nearest square
	my @erts;
	my $color = MapDraw::incColor();
	foreach (@exits) {
		my $dest = getClosest($screen,$_,@squares);
		my @steps = getRoute($screen,$_,$dest,map => $g,color => $color, fill => MapDraw::incColor());
		push(@erts,@steps);
	}
	push (@routes,@erts);
	$nr += scalar @exits;
#	foreach (@exits) {
#		my ($points,$x,$y,$fill) = MapDraw::pointify($screen,$_,0,0);
#		my $text = $_->{text};
#		MapDraw::formLayerObject(1,'polygon',[$points,],x => $x,y => $y, text => $text, coords => 1, fill => $fill, loc => $_->loc);
#	}
	# choose side roads
	# look for places to add minor roads
	# return or draw map
	my $size = scalar @routes;
	if (1) { print "Checking for duplicate routes..."; }
	@routes = Points::seg_remove_dup(\@routes,0); # trim out duplicate segments to make drawing more efficient
	if (1) { print "Removed " . ($size - scalar @routes) . " duplicate route" . ($size - scalar @routes == 1 ? "" : "s") . ".\n"; }
	return $nr,@routes;
}

sub getRoute { # shorthand
	my ($scr,$start,$end,%args) = @_;
	unless (defined($start) && ref($start) =~ m/Hex/) {
		die "No starting hex for getRoute!";
	}
	unless (defined($end) && ref($end) =~ m/Hex/) {
		die "No ending hex for getRoute!";
	}
	return $scr->hexlist_to_lines($args{color},$start->hex_linedraw($end,%args));
}

sub connectSqsHex {
	my ($screen,$routes,$map,%args) = @_;
	my @hexrts;
	foreach my $h (@$routes) {
		my $sv = Vertex->new(undef,"StartV",$h->ox,$h->oy);
		my $ev = Vertex->new(undef,"EndV",$h->ex,$h->ey);
print "\n" . $sv->describe(1);
print "\n" . $ev->describe(1);
printf("%d,%d - %d,%d\n",$h->ox,$h->oy,$h->ex,$h->ey);
		my $sd = $screen->pixel_to_hex($sv);
		my $ed = $screen->pixel_to_hex($ev);
		$sd = $sd->hex_round();
		$ed = $ed->hex_round();
printf("%s - %s\n",$sd->loc,$ed->loc);
		if (defined($map)) {
			$args{map} = $map;
			$args{color} = "#6cc" unless defined ($args{color});
		}
		push(@hexrts,getRoute($screen,$sd,$ed,%args));
	}
	if (1) { # orient lines
		foreach (@hexrts) {
			$_->orient(0); # orient line south (or east)
		}
	}
	return @hexrts;
}

sub pickExitHexes {
	my ($hiw,$screen,$map,@colist) = @_;
	my $order = $map->{order};
	my $center = $map->{grid}->{center};
	print "I need to pick $hiw exits from " . scalar @colist . " options...\n";
	my @exits;
	my $listindex = $center->intpairs_to_azimuth($screen,$order,@colist);
#	foreach my $i (0 .. $#colist) {
#		printf("%d,%d: %.3f\n",@{$colist[$i]},$$listindex[$i]);
#	}
	my ($sortedcolist,$sortedindex) = Common::listSort($listindex,@colist);
#	foreach my $i (0 .. $#$sortedcolist) {
#		printf("%d,%d- %.3f\n",@{$$sortedcolist[$i]},$$sortedindex[$i]);
#	}
	my $max = scalar @colist; # how many exits do we have to choose from?
	my $spread = ($hiw < $max/6); # do we not have too many exits to spread?
	use List::Util qw( min max );
	my $range = int($max/6)-3; # how far apart can they be?
	my $interval = max($range+1,1);
	$range = max($range,1);
	my $start = floor(rand(1000));
# print "RI: $spread H: $hiw M: $max R: $range I: $interval S: $start\n";
	foreach my $i (1 .. $hiw) {
		$start = $start % $max;
		push(@exits,$start);
# print "Placing exit at $start: " . join(',',@{$$sortedcolist[$start]}) . "\n";
		$start += ($spread ? # worry about clustering?
			floor(rand($range)) + 2 : # 2 makes adjacent exits very unlikely
			$interval ); # too many exits; just increase minimum
	}
	foreach (0 .. $#exits) { # translate coords to hexes
		$exits[$_] = Hexagon::placeHex($order,@{$$sortedcolist[$exits[$_]]},name => "#f00");
	}
	return @exits;
}

sub getClosest {
	my ($scr,$h,@hlist) = @_;
	my @dists;
	foreach (@hlist) {
		push(@dists,$h->distance($scr->pixel_to_hex($_,1)));
	}
	my $minind = -1; # index of minimum
	my $mindis = 9999999; # minimum distance
	foreach (0 .. $#hlist) { # magic: reset index and minimum, if less than current.
		($mindis > $dists[$_]) && ($mindis = $dists[$_]) && ($minind = $_);
	}
	printf("Closest to %s is %d:%s (%d hexes)\n",$h->loc,$minind,$scr->pixel_to_hex($hlist[$minind])->hex_round()->loc,$mindis);
	($minind < 0) && die "Wat! (shouldn't happen unless user passed empty array or something stupid like that)";
	return $scr->pixel_to_hex($hlist[$minind],1);
}

sub drawHexAt {
	my ($screen,$v,%exargs) = @_;
	return drawThisHex($screen,$screen->pixel_to_hex($v)->hex_round,%exargs);
}

sub drawThisHex {
	my ($screen,$h,%exargs) = @_;
	my ($points,$x,$y,$fill) = MapDraw::pointify($screen,$h);
	my $v = $screen->hex_to_pixel($h);
	my $text = sprintf("%d,%d",$h->intloc());
printf("Drawing Hex At %d,%d => H(%s)\n",$v->x,$v->y,$text);
	if ($exargs{autoloc}) {
		$exargs{loc} = join(',',$v->loc);
#	} else {
#		print Common::lineNo();
	}
	MapDraw::formLayerObject(1,'polygon',[$points,],x => ($x or 0),y => ($y or 0), text => $text, coords => 1, fill => $fill, %exargs);
	return 0;
}

sub drawHexPOI {
	my ($screen,$h,$z) = @_;
	my $v = $screen->hex_to_pixel($h);
	return drawPOI($v,$z)
}

sub drawPOI { # expects (Vertex,Hashref) or (int,int,Hashref)
	# where hashref contains: (r)adius, (s)troke color, and/or (f)ill color
	my ($x,$y,$z) = @_;
	my %args = %{ ((ref($x) eq "Vertex" ? $y : $z ) or { r => 5 }) };
	my %circle = ();
	$circle{x} = (ref($x) eq "Vertex" ? $x->x : $x );
	$circle{y} = (ref($x) eq "Vertex" ? $x->y : $y );
#printf("Drawing Circle Around %d,%d\n",$circle{x},$circle{y});
	foreach my $k (keys %args) {
		if ($k eq 'r') {
			$circle{$k} = $args{$k};
		} elsif ($k eq 's') {
			$circle{stroke} = $args{$k};
		} elsif ($k eq 'f') {
			$circle{fill} = $args{$k};
		}
	}
	$circle{r} = 5 unless (defined $circle{r}); # default radius
	MapDraw::formLayerObject(2,'circle',[\%circle,]);
}

sub trimDuplicates { # duplicate hexes
	my ($array,%exargs) = @_;
# TODO: make a new array, check each new entry for duplication

	return @$array;
}

sub open_neighbors_with_count {
	my ($g,$h) = @_;
	my $mask = $g->open_neighbors($h);
	my @nei = Common::expandMask($mask);
	my $count = scalar @nei;
	return ($mask,$count,@nei);
}

sub branchInnerHex {
	my ($secondratio,$screen,$grid,@bigroads) = @_;
	my $color = "#808099";
	my @sides;
	foreach my $k (keys %{ $grid->{grid} }) {
		my $h = $grid->{grid}{$k};
		my ($mask,$count,@nei) = open_neighbors_with_count($grid,$h);
		$count < 2 && next; # no sideroad if only one open hex
		my $choice = int(rand(12))%$#nei;
		my @nl = $grid->neighbor_toward($h,$nei[$choice]);
		my $n = $grid->add_hex_at(@nl,name => sprintf("%d,%d",@nl), fill => $color);
		my ($maskn,$countn,@nein) = open_neighbors_with_count($grid,$n);
		my $sn;
print "\n:::" . $h->loc . ": ";
		if ($countn) {
			my @snl = $grid->neighbor_toward($n,$nei[$choice]);
			$sn = $grid->add_hex_at(@snl,name => sprintf("%d,%d",@snl), fill => $color);
print "[" . $n->loc . "}{" . $sn->loc . "]";
			push(@sides,$screen->hexlist_to_lines($color,$sn,$n,$h));
		} else {
			my @snl = $grid->neighbor_toward($h,$nei[$choice + 1 + int(rand($count - 1))]);
			$sn = $grid->add_hex_at(@snl,name => sprintf("%d,%d",@snl), fill => $color);
print $n->loc . " () " . $sn->loc;
			push(@sides,$screen->hexlist_to_lines($color,$sn,$h,$n));
		}
	}
print "===\n";
	return @sides;
}

sub branchOuterHex {
	if ($debug) { print "branchInnerHex(@_);"; }
	my ($secondratio,$bearvar,$factor,$scale,@bigroads) = @_;
	my @smallroads;
	my $sidestomake = $secondratio;
	my $posrange = 1/($sidestomake + 2);
	my @positions;
	my $variance = $posrange / 5 + 0.01;
	foreach my $i (0 .. $sidestomake) {
		push(@positions,($posrange * ($i + 1)) - $variance + (rand($variance * 2)));
	}
	my $sidesperroad = (int($sidestomake / @bigroads) or 1);
	my $sidesmade = 0;
	my $brnum = 0;
	foreach my $r (@bigroads) {
		foreach (0 .. $sidesperroad) {
			next if ($sidesmade >= $sidestomake);
			my $id = scalar(@bigroads)+scalar(@smallroads);
			my $bear = $r->azimuth();
			my $sideroad = Segment->new($id,sprintf("%.2f Road %d",$bear,$id));
#		choose a point on highway
			my $intersection = Points::findOnLine($r->ex(),$r->ey(),$r->ox(),$r->oy(),Common::fmod($positions[$sidesmade] * scalar @bigroads,1.0));
#		choose a distance for the road to extend
			my $len = int($factor * $scale * (rand(1) + 1.2));
			addSideHereAlt($intersection,$sideroad,$len,$bearvar,$bear,75); # 100=chance of doubling?
#		(check for bad juxtapositions?)
			adjustSideRoad($sideroad,20,@smallroads);
#		add road to route list
			push(@smallroads,$sideroad);
			$sidesmade++;
		}
		$brnum++;
	}
	return @smallroads;
}

sub addSideHereAlt {
	my ($intersection,$road,$length,$variance,$bear,$doublechance) = @_;
#		choose a bearing coming off the highway
	my @azchoice = (90 - $variance,90,90 + $variance,270 - $variance,270,270 + $variance);
	my $az = $azchoice[rand(7) % scalar @azchoice];
	my $endpoint = Points::choosePointAtDist($intersection->x(),$intersection->y(),$length,$az - 3,$az + 3,$bear);
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

1;
