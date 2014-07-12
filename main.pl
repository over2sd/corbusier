#!/usr/bin/perl
use strict;

use Points;
use MapDes;
#use MapDraw;

use Getopt::Long;

sub main {
    my $gui = 0; # show the gui?
    my $hiw = 5; # number of highways leading out of town
    my $sec = 7; # number of main roads branching off the highways
    my $rat = 3; # ratio of smaller roads per secondary
    my $depth = 3; # how many substreets deep should we go?
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
    if (!$max) { $max = $hiw * $sec; }
    if ($gui) {
#        use MapGUI;
        showGUI();
    } else {
        my ($nr,@routes) = MapDes::genmap($hiw,$sec,$rat,$poi,$max,$w,$h);
#        my @poi = 
    }
}

main();