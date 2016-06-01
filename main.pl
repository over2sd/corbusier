#!/usr/bin/perl
use strict;

use Points;
use MapDes;
use MapDraw;
use Common;
use Hexagon;

use Getopt::Long;

my %bgfill = ( 'r' => 255, 'g' => 255, 'b' => 255 );

sub mapSeed {
		my ($highways,$secondaries,$ratio,$pointsofinterest,$maxroads,$width,$height,$seed,$centertype,$showtheseed,$offsetx,$offsety,$forcecrossroads,$hexes,$grid,$scr) = @_;
		srand($seed);
        print "Using map seed $seed...\n";
		my ($nr,@routes);
		if ($hexes) {
			($nr,@routes) = MapDes::genHexMap($highways,$secondaries,$ratio,$pointsofinterest,$maxroads,$centertype,$forcecrossroads,$grid,$scr);
		} else {
			($nr,@routes) = MapDes::genmap($highways,$secondaries,$ratio,$pointsofinterest,$maxroads,$centertype,$forcecrossroads);
		}
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
		if ($hexes) {
			$exargs{'grid'} = $grid;
			$exargs{'screen'} = $scr;
			my @center = $scr->center();
			$exargs{'center'} = \@center;
		}
		@routes = MapDes::trimDuplicates(\@routes,(chkreverse => 1));
        MapDraw::formSVG($width,$height,\@routes,\@boxen,%exargs);
}

sub main {
    my $gui = 0; # show the gui?
    my $hiw = 5; # number of highways leading out of town
    my $sec = 7; # number of main roads branching off the highways
    my $rat = 3; # ratio of smaller roads per secondary
    my $depth = 3; # how many substreets deep should we go?
    my $poi = 0; # use points of interest instead of branching
    my $max = 0; # maximum number of roads in total. If not set as an option, this will be equal to highways * secondaries.
    my $seed = 0; # -1; # Negative = random seed/map number
    my $w = 800; # Width of image
    my $h = 600; # Height of image
    my $hex = 1; # generate a map for use with a hex grid
    my $grid = 32; # how big is the grid (diagonals/rows)
	my $grid2 = 0;
	my $shape = 'hexb'; # shape of hex grid
	my $order = 0; # hex grid parameter order (0-5)
	my $scale = 15; # what radius does each hex have?
    my $fn = 'output.svg'; # Filename of map
	my $disp = 0; # display seed on map (debug function)
	my @seedlist; # list of seeds, read from file
	my $listfn = ''; # filename for list of seeds
	my $showhelp = 0;
	my $crossroadssquare = 0; # secondaries and side roads meet larger roads at close to 90 degrees.
	my $centertype = 0; # type of map to generate -=- default center mode
	my ($map,$screen); # needed for hex maps.
	my $joins = 4; # how many squares to build (used only by GUI);
							$disp = 1; # for development. TODO: Remove this line when done tweaking generator
    GetOptions(
		'help' => \$showhelp,
        'gui' => \$gui,
	'scale|1=i' => \$scale,
		'comp|c=s' => \$listfn,
        'depth|d=i' => \$depth,
        'highways|exits|e=i' => \$hiw,
        'file|f=s' => \$fn,
	'cells|g=i' => \$grid,
	'cellshigh|i=i' => \$grid2,
		'listseed|l' => \$disp,
        'map|m=i' => \$seed,
	'hexagonal|n' => \$hex,
	'order|o=i' => \$order,
        'poimode|p' => \$poi,
		'squareint|q=i' => \$crossroadssquare,
        'ratio|r=i' => \$rat,
        'secondary|s=i' => \$sec,
		'type|t=i' => \$centertype,
        'max|x=i' => \$max,
	'shape|y=s' => \$shape,
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
        use MapGUI;
        MapGUI::showGUI(
			w => $w, h => $h, seed => $seed, joins => $joins,
			hex => $hex, rows => $grid, cols => $grid2, shape => $shape,
			hexorder => $order, radius => $scale, hexor => 'left',
			exits => $hiw, sec => $sec, ratio => $rat, depth => $depth,
			);
    } else {
		my $svg = '';
		Points::setCornerHeadings($w,$h); # set boundaries for use multiple times.
		MapDes::setMDConf("width",$w,"height",$h);
		MapDes::setMDConf("centerx",int((0.5 + $w)/2),"centery",int((0.5 + $h)/2));
		if ($listfn ne '') {
			@seedlist = Common::loadSeedsFrom($listfn);
		}
		if ($hex) {
#TODO: make a flag that will allow this limit to be overridden.
			$map= Hexagon::Map->new($shape,$order,$grid,($grid2 or $grid));
# TODO: hex orientation flag
			$screen = Hexagon::Screen->new('left',$scale,$scale,$map->req_offset($scale),MapDes::getCenter());
#			$map->generate("none");
			$map->addCenter("#f0f");
		}
		if (@seedlist) {
# Start of seed loop
			my ($x,$y) = (0,0);
			my $width = Common::selectWidth($w,scalar(@seedlist));
			foreach my $seed (@seedlist) {
				mapSeed($hiw,$sec,$rat,$poi,$max,$w,$h,$seed,$centertype,$disp,$x,$y,$crossroadssquare,$hex,$map,$screen);
				$x += $w;
				if ($x >= $width) {
					$x = 0;
					$y += $h;
				}
# End of seed loop
			}
		} else {
			mapSeed($hiw,$sec,$rat,$poi,$max,$w,$h,$seed,$centertype,$disp,0,0,$crossroadssquare,$hex,$map,$screen);
		}
		my $svg = MapDraw::getSVGLayers();
        my ($result,$errstr) = MapDraw::saveSVG($svg,$fn);
        if ($result != 0) { print "Map could not be saved: $errstr"; }
        print "\n";
    }
}

main();
