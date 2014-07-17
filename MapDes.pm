use strict;

package MapDes;
use Points;

use POSIX qw( floor );
use List::Util qw( min );
my $debug = 1;

sub costlyRectify {
    my ($ar,$v) = @_;
    my @existing = @$ar;
    my @xs;
    my @ys;
    foreach my $i (0 .. $#existing) {
        push(@xs,$existing[$i]->x());
		push(@ys,$existing[$i]->y());
    }
	my $basex = min(@xs) - 20;
	my $topx = max(@xs) + 20;
	my $basey = min(@ys) - 20;
	my $topy = max(@ys) + 20;
	my @xpoints = ($basex .. $topx);
	my @ypoints = ($basey .. $topy);
    foreach my $i (0 .. $#existing) {
		splice(@xpoints,$existing[$i]->x() - 5,10);
		splice(@ypoints,$existing[$i]->y() - 5,10);
    }
	use Data::Dumper;
	print Dumper @xpoints;
	$v->move(0,0);
	return $v;
}

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

sub branchmap {
    if ($debug) { print "branchmap(@_)\n"; }
    my ($hiw,$sec,$rat,$poi,$max,$w,$h) =  @_;
    if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
    my $numroutes = 0;
    my @sqs;
    my @rts;
    my @poi;
    my $mxj = $hiw > 10 ? 5 : 3;
    my $joins = floor(rand($mxj)) + 1; # choose number of intersections
    if ($debug) { print "  Joins: " . $joins . "/" . $mxj . "\n"; }
    $mxj = floor($w / 4);
    my $myj = floor($h / 4);
    foreach my $i (0 .. $joins - 1) { # choose joining point(s)
        my ($d,$j,$x,$y) = 0,0,0,0;
        my $v = Vertex->new($i);
        do {
            $x = floor(rand(2 * $mxj)) + $mxj;
            $y = floor(rand(2 * $myj)) + $myj;
            $v->move($x,$y);
            $d = 21;
            foreach my $ii (@sqs) {
                $d = min($d,Points::getDist($ii->x(),$ii->y(),$v->x(),$v->y()));
            }
            if ($j > 5) { $v->move(costlyRectify(\@sqs,$v)); $x = $v->x(); $y = $v->y(); }
        } until ($d > ($w > 125 ? 20 : 5) or $j > $joins * 10); # minimum distance between squares
        if ($x != 0 and $y != 0) {
		   push(@sqs,$v);
        }
    }
    my @irts;
    my $lowindex = 0;
    # find point closest to center
    # later, add options to have "center" be closest to one corner, instead, or a random point instead of the most central.
    my @center = (floor($w / 2),floor($h / 2));
    $lowindex = Points::getClosest(@center,\@sqs);
    foreach my $i (0 .. $#sqs) {     # link point to all other points
        if ($i != $lowindex) {
		   my $line = Segment->new($numroutes);
           $numroutes += 1;
		   $line->set_ends($sqs[$i]->x(),$sqs[$lowindex]->x(),$sqs[$i]->y(),$sqs[$lowindex]->y());
            $line->immobilize();
#		      Save these highways to a separate list that will be added to the end of the routes, so other roads don't come off them.
		   push(@irts,$line)
        }
    }
# place highways

# count junctions
	my $divisor = $#sqs;
# if more than two, delete the one most central from list
	if ($divisor > 1) { # more than two junctions
		delete $sqs[$lowindex]; # delete central junction (already has roads coming off it)
	}
# divide highways among remaining junctions
	my $rem = $hiw - (int($hiw/$divisor) * $divisor);	
	my @histogrow;
	foreach my $i (0 .. $divisor) {
		push(@histogrow,int($hiw/$divisor) + ($i > 0 ? 0 : $rem));
	}
	my $i = 0;
	while (scalar(@sqs) != 0) {
		$i += 1;
# shift out a vertex and a number of highways to grow from it
		my $nh = shift @histogrow;
		my $v = shift @sqs;
# find closest compass direction
		while ($nh > 0) {
			my ($fx,$fy,$xfirst,$edge) = 1,1,1,0;
			my $exside = Points::closestCardinal($v->x(),$v->y(),$w,$h);
			print "Highway $hiw is exiting: $exside\n";
			$hiw -= 1;
			for ($exside) {
				if (/2/) { $fx = -1; $xfirst = 0; $edge = $w; }
				elsif (/3/) { $fx = -1; $xfirst = 0; $edge = $w; }
				elsif (/4/) { $fx = -1; $fy = -1; $edge = $h; }
				elsif (/5/) { $fx = -1; $fy = -1; $edge = $h; }
				elsif (/6/) { $fy = -1; $xfirst = 0; }
				elsif (/7/) { $fy = -1; $xfirst = 0; }
			}
# grow a highway to a point on the edge
			my ($x,$y);
# (x (or y for E/W) +/- .25x)
			my $base = ($xfirst ? $v->x() : $v->y());
			my $mate = ($xfirst ? $v->y() : $v->x());
			print "Edge: $base ";
			my $r = int(rand($base/2));
			print "($r) ";
			$base = $base - floor($base / 4) + $r * ($xfirst ? $fx : $fy);
			print "=> $base :: $edge\n";
# If total is greater than h (or w), trim, and push away from edge with excess
			if ($base > ($xfirst ? $w : $h)) {
				my $rem = $base - ($xfirst ? $w : $h) * ($xfirst ? $fy : $fx); # mate, so reverse order
				$mate += $rem;
			}
			($x,$y) = ($base,$mate);
			print "Edge pair for (" . $v->x() . "," . $v->y() . ") is now ($x,$y).\n";
			$nh -= 1;
		}
		if ($i > 100) { exit(-1); }
	}
	exit(0);
    while ($hiw > 0) {
        my $exitx = 0;
        my $exity = 0;
#    check distance from exit to each join
        $lowindex = Points::getClosest($exitx,$exity,\@sqs);
#        highways will go from exit to closest join
		my $line = Segment->new($numroutes);
		$line->set_ends($exitx,$sqs[$lowindex]->x(),$exity,$sqs[$lowindex]->y());
        $numroutes += 1;
        $hiw -= 1;
#    add highway to route list
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
    foreach my $i (0 .. $#irts) {
        push(@rts,$irts[$i]);
    }
    return $numroutes,@rts;
}

1;