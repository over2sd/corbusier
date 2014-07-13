use strict;

package MapDes;
use Points;

use POSIX qw( floor );
use List::Util qw( min );

sub genmap {
    my ($hiw,$sec,$rat,$poi,$max,$w,$h) =  @_;
    if ($hiw < 1) { return 0,undef; } # Have to have at least one highway leaving town.
    my $numroutes = 0;
    my @sqs;
    my @rts;
    my @poi;
    my $mxj = $hiw > 10 ? 3 : 2;
    my $joins = floor(rand($mxj)) + 1; # choose number of intersections
#    print "Joins: " . $joins . "\n";
    $mxj = floor($w / 3);
    my $myj = floor($h / 3);
    foreach my $i (0 .. $joins - 1) { # choose joining point(s)
        my ($d,$j,$x,$y) = 0,0,0,0;
        do {
            $x = floor(rand($mxj)) + $mxj;
            $y = floor(rand($myj)) + $myj;
            if ($#sqs) {
                foreach my $ii (0 .. $#sqs) {
                    $d = min($d,getDist(@{$ii}[0],@{$ii}[1],$x,$y));
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
    my @center = (floor($w / 2),floor($h / 2));
    $lowindex = Points::getClosest(@center,undef,undef,@sqs);
    foreach my $i (0 .. $#sqs) {     # link point to all other points
        if ($i != $lowindex) {
            
        }
    }
=for pseudo
place highways
    check distance from exit to join
        highways will go from exit to closest join
    add highway to route list
    Additional interior highways will connect joins to each other
        Save these highways to a separate list that will be added to the end of the routes, so other roads don\'t come off them.
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
    return $numroutes,@rts;
}

1;