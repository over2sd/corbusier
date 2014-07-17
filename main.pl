#!/usr/bin/perl
use strict;

use Points;
use MapDes;
use MapDraw;

use Getopt::Long;

sub main {
    my $gui = 0; # show the gui?
    my $hiw = 5; # number of highways leading out of town
    my $sec = 7; # number of main roads branching off the highways
    my $rat = 3; # ratio of smaller roads per secondary
    my $depth = 3; # how many substreets deep should we go?
    my $poi = 0; # use points of interest instead of branching
    my $max = 0; # maximum number of roads in total. If not set as an option, this will be equal to highways * secondaries.
    my $seed = 0; # Random seed/map number
    my $w = 800; # Width of image
    my $h = 600; # Height of image
    my $fn = 'output.svg'; # Filename of map
    GetOptions(
        'gui' => \$gui,
        'depth|d=i' => \$depth,
        'highways|exits|e=i' => \$hiw,
        'file|f=s' => \$fn,
        'map|m=i' => \$seed,
        'poimode|p' => \$poi,
        'ratio|r=i' => \$rat,
        'secondary|s=i' => \$sec,
        'max|x=i' => \$max,
        'w=i' => \$w,
        'h=i' => \$h
        );
    if ($seed == 0) { $seed =  time }
    srand($seed);
    if (!$max) { $max = $hiw * $sec; }
    if ($gui) {
#        use MapGUI;
        showGUI();
    } else {
        print "Using map seed $seed...\n";
        my ($nr,@routes) = MapDes::genmap($hiw,$sec,$rat,$poi,$max,$w,$h);
#        my @poi = 
        print "- $nr routes\n";
        foreach my $i (0 .. $#routes) {
            print $routes[$i]->describe(1) . "\n";
        }
        my $svg = MapDraw::formSVG(\@routes);
        my ($result,$errstr) = MapDraw::saveSVG($svg,$fn);
        if ($result != 0) { print "Map could not be saved: $errstr"; }
        print "\n";
    }
}

main();