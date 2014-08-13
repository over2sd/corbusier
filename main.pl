#!/usr/bin/perl
use strict;

use Points;
use MapDes;
use MapDraw;
use Common;

use Getopt::Long;

my %bgfill = ( 'r' => 255, 'g' => 255, 'b' => 255 );

sub mapSeed {
		my ($highways,$secondaries,$ratio,$pointsofinterest,$maxroads,$width,$height,$seed,$centertype,$showtheseed,$offsetx,$offsety,$forcecrossroads) = @_;
		srand($seed);
        print "Using map seed $seed...\n";
        my ($nr,@routes) = MapDes::genmap($highways,$secondaries,$ratio,$pointsofinterest,$maxroads,$centertype,$forcecrossroads);
#        my @poi = 
#		print "- $nr routes\n";
#		foreach my $i (0 .. $#routes) {
#            print $routes[$i]->describe(1) . "\n";
#		}
		my @boxen;
		$bgfill{'r'} -= $seed % 255; if ($bgfill{'r'} < 0) { $bgfill{'r'} += 256; }
		my $fillcolor = sprintf("#%02x%02x%02x",$bgfill{'r'}, $bgfill{'g'}, $bgfill{'b'});
		my %bgbox; $bgbox{'x'} = 0; $bgbox{'y'} = 0; $bgbox{'w'} = $width; $bgbox{'h'} = $height; $bgbox{'f'} = $fillcolor;
		push (@boxen,\%bgbox);
		my %exargs;
		if ($showtheseed) { $exargs{'seed'} = $seed; }
		if ($offsetx) { $exargs{'xoff'} = $offsetx; }
		if ($offsety) { $exargs{'yoff'} = $offsety; }
        my $out = MapDraw::formSVG($width,$height,\@routes,\@boxen,%exargs);
		return $out;
}

sub main {
    my $gui = 0; # show the gui?
    my $hiw = 5; # number of highways leading out of town
    my $sec = 7; # number of main roads branching off the highways
    my $rat = 3; # ratio of smaller roads per secondary
    my $depth = 3; # how many substreets deep should we go?
    my $poi = 0; # use points of interest instead of branching
    my $max = 0; # maximum number of roads in total. If not set as an option, this will be equal to highways * secondaries.
    my $seed = -1; # Random seed/map number
    my $w = 800; # Width of image
    my $h = 600; # Height of image
    my $fn = 'output.svg'; # Filename of map
	my $disp = 0; # display seed on map (debug function)
	my @seedlist; # list of seeds, read from file
	my $listfn = ''; # filename for list of seeds
	my $showhelp = 0;
	my $crossroadssquare = 0; # secondaries and side roads meet larger roads at close to 90 degrees.
	my $centertype = 0; # type of map to generate -=- default center mode
							$disp = 1; # for development. TODO: Remove this line when done tweaking generator
    GetOptions(
		'help' => \$showhelp,
        'gui' => \$gui,
		'comp|c=s' => \$listfn,
        'depth|d=i' => \$depth,
        'highways|exits|e=i' => \$hiw,
        'file|f=s' => \$fn,
		'listseed|l' => \$disp,
        'map|m=i' => \$seed,
        'poimode|p' => \$poi,
		'squareint|q' => \$crossroadssquare,
        'ratio|r=i' => \$rat,
        'secondary|s=i' => \$sec,
		'type|t=i' => \$centertype,
        'max|x=i' => \$max,
        'w=i' => \$w,
        'h=i' => \$h
        );
	if ($showhelp) {
		print "Help not yet written. Sorry. Smack the dev(s).\n";
		exit(0);
	}
    if ($seed < 0) { $seed =  time }
    if (!$max) { $max = $hiw * $sec; }
    if ($gui) {
# most other options are ignored, if gui will be shown.
#        use MapGUI;
        showGUI();
    } else {
		my $svg = '';
		Points::setCornerHeadings($w,$h); # set boundaries for use multiple times.
		MapDes::setMDConf("width",$w,"height",$h);
		MapDes::setMDConf("centerx",\(int((0.5 + $w)/2),"centery",int((0.5 + $h)/2)));
		if ($listfn ne '') {
			@seedlist = Common::loadSeedsFrom($listfn);
		}
		 if (@seedlist) {
# Start of seed loop
			my @svglist;
			my ($x,$y) = (0,0);
			my $width = Common::selectWidth($w,scalar(@seedlist));
			foreach my $seed (@seedlist) {
				my $svgstring= mapSeed($hiw,$sec,$rat,$poi,$max,$w,$h,$seed,$centertype,$disp,$x,$y,$crossroadssquare);
				push(@svglist,$svgstring);
				$x += $w;
				if ($x >= $width) {
					$x = 0;
					$y += $h;
				}
# End of seed loop
			}
			foreach my $add (@svglist) {
				$svg = "$svg$add\n";
			}
		} else {
			$svg = mapSeed($hiw,$sec,$rat,$poi,$max,$w,$h,$seed,$centertype,$disp,0,0,$crossroadssquare);
		}
        my ($result,$errstr) = MapDraw::saveSVG($svg,$fn);
        if ($result != 0) { print "Map could not be saved: $errstr"; }
        print "\n";
    }
}

main();