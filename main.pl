#!/usr/bin/perl

use Points;
use MapDes;
use MapDraw;

use Getopt::Long;

sub main {
    my $gui = 0; # show the gui?
    my $hiw = 5; # number of highways leading out of town
    my $sec = 7; # number of main roads branching off the highways
    my $rat = 3; # ratio of smaller roads per secondary
    my $poi = 0; # use points of interest instead of branching
    my $max = 0; # maximum number of roads in total. If not set as an option, this will be equal to highways * secondaries.
    my $w = 800; # Width of image
    my $h = 600; # Height of image
    GetOptions(
        'gui' => \$gui,
        'highways|exits|e=i' => \$hiw,
        'secondary|s=i' => \$sec,
        'ratio|r=i' => \$rat,
        'w=i' => \$w,
        'h=i' => \$h,
        'depth|d=i' => \$depth,
        'max|x=i' => \$max,
        'poimode|p' => \$poi
        );
    }
    if (!$max) { $max = $hiw * $sec; }
    if ($gui) {
        use MapGUI;
        showGUI();
    } else {
        my ($nr,@routes) = genmap($hiw,$sec,$rat,$poi,$max,$w,$h);
#        my @poi = 
    }
}

sub genmap {
    my ($hiw,$sec,$rat,$poi,$max,$w,$h) =  @_;
    my $numroutes = 0;
    my @rts;
    my @poi;
'''
choose number of intersections
choose joining point(s)
place highways
    check distance from exit to join
        2/3 of highways will go from exit to closest join
    add highway to route list
    If joins do not connect, additional interior highways will connect joins to closest unconnected highways
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
'''
    return $numroutes,@rts;
}

main();