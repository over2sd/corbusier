use strict;

package MapDes;
use Points;

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

sub branchmap {
    if ($debug) { print "branchmap(@_)\n"; }
    my ($hiw,$sec,$rat,$poi,$max,$w,$h) =  @_;
    if ($hiw < 1) { print "0 exits\n"; return 0,undef; } # Have to have at least one highway leaving town.
    my $numroutes = 0;
    my @sqs;
    my @rts;
    my @poi;
    my $mxj = $hiw > 10 ? 3 : 2;
    my $joins = floor(rand($mxj)) + 1; # choose number of intersections
    if ($debug) { print "  Joins: " . $joins . "/" . $mxj . "\n"; }
    $mxj = floor($w / 4);
    my $myj = floor($h / 4);
    foreach my $i (0 .. $joins - 1) { # choose joining point(s)
        my ($d,$j,$x,$y) = 0,0,0,0;
        do {
            $x = floor(rand(2 * $mxj)) + $mxj;
            $y = floor(rand(2 * $myj)) + $myj;
		    if ($#sqs) {
		       foreach my $ii (0 .. $#sqs) {
				  $d = min($d,Points::getDist($sqs[$ii][0],$sqs[$ii][1],$x,$y));
		       }
		       $j += 1;
		   } else {
		       $d = 21;
		   }
        } until ($d > ($w > 125 ? 20 : 5) or $j > $joins * 10); # minimum distance between squares
        if ($x != 0 and $y != 0) {
		   push(@sqs,[$x,$y]);
        }
    }
    my @irts;
    my $lowindex = 0;
    # find point closest to center
    # later, add options to have "center" be closest to one corner, instead, or a random point instead of the most central.
    my @center = (floor($w / 2),floor($h / 2));
    $lowindex = Points::getClosest(@center,undef,undef,@sqs);
    foreach my $i (0 .. $#sqs) {     # link point to all other points
        if ($i != $lowindex) {
		   my $line = Segment->new($numroutes);
           $numroutes += 1;
		   $line->set_ends($sqs[$i][0],$sqs[$i][1],$sqs[$lowindex][0],$sqs[$lowindex][1]);
            $line->immobilize();
#		      Save these highways to a separate list that will be added to the end of the routes, so other roads don't come off them.
		   push(@irts,$line)
        }
    }
# place highways
    my $w3 = floor($w / 3);
    my $h3 = floor($h / 3);
    my @exitsleft = (2,5,8,11,3,6,9,0,4,7,1,10);
    my $exitrandomly = 1;
    if ($hiw > 12) {
        $exitrandomly = 0;
        while ($#exitsleft < $hiw) {
            @exitsleft = (@exitsleft,(0,2,4,6,8,10,1,3,5,7,9,11));
        }
        $#exitsleft = $hiw; # truncate the array
    }
    while ($hiw > 0) {
        my $exitx = 0;
        my $exity = 0;
        my $exside = 0;
        if ($exitrandomly) {
            $exside = int(rand(12));
        } else {
            int(rand(2)) ? $exside = pop(@exitsleft) : shift(@exitsleft);
        }
        print "Highway $hiw is exiting: $exside\n";
        for ($exside) {
		   if (/1/) { $exitx = int(rand($w3)); }
		   elsif (/2/) { $exitx = int(rand($w3)) + $w3; }
		   elsif (/3/) { $exitx = int(rand($w3)) + 2 * $w3; }
		   elsif (/4/) { $exitx = $w; $exity = int(rand($h3)); }
		   elsif (/5/) { $exitx = $w; $exity = int(rand($h3)) + $h3; }
		   elsif (/6/) { $exitx = $w; $exity = int(rand($h3)) + 2 * $h3; }
		   elsif (/7/) { $exitx = int(rand($w3)) + 2 * $w3; $exity = $h; }
		   elsif (/8/) { $exitx = int(rand($w3)) + $w3; $exity = $h; }
		   elsif (/9/) { $exitx = int(rand($w3)); $exity = $h; }
		   elsif (/10/) { $exity = int(rand($h3)) + 2 * $h3; }
		   elsif (/11/) { $exity = int(rand($h3)) + $h3; }
		   else { $exity = int(rand($h3)); }
        }
#    check distance from exit to each join
        $lowindex = Points::getClosest($exitx,$exity,undef,undef,@sqs);
#        highways will go from exit to closest join
		my $line = Segment->new($numroutes);
		$line->set_ends($exitx,$exity,$sqs[$lowindex][0],$sqs[$lowindex][1]);
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