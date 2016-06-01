package MapGUI;
use strict;

use List::Util qw( min max );
use Points;
use Common;
use Tk;
use Tk::NoteBook;
use Tk::LabFrame;
use Tk::Canvas;

my %windowset;
sub createMainWin {
	my ($program,$version,$w,$h) = @_;
	my $mw = MainWindow->new( -title => "$program $version");
	$mw->geometry("${w}x$h+10+10");
	$windowset{mainWin} = $mw;
	return \%windowset;
}
print ".";

sub labelframe_children {
	# Enables/disables children in a frame
	# based on a checkbox's state
	my ($lf,$cb,$var_ref) = @_;
	foreach my $c ($lf->children) {
		next if ($c == $cb);
		if ($$var_ref) {
			$c->configure(qw/-state normal/);
		} else {
			$c->configure(qw/-state disabled/);
		}
	}
}

sub showGUI {
	my (%args) = @_;
	my $gui = createMainWin("Corbusier","v0.1",640,540);
=item comment
    my $poi = 0; # use points of interest instead of branching
    my $max = 0; # maximum number of roads in total. If not set as an option, this will be equal to highways * secondaries.
    my $fn = 'output.svg'; # Filename of map
	my $disp = 0; # display seed on map (debug function)
	my $showhelp = 0;
	my $crossroadssquare = 0; # secondaries and side roads meet larger roads at close to 90 degrees.
	my ($map,$screen); # needed for hex maps.
=cut

	my $win = $$gui{mainWin};
	my %data;
	$win->protocol('WM_DELETE_WINDOW',sub {
		use Data::Dumper;
		print "Current Data:\n";
#		print Dumper \%data;
		print join(', ',sort keys %data);
		foreach my $key (qw/joins joincolor exitn outhex exits/) {
			next unless exists $data{$key};
			print "\n$key:" . (ref($data{$key}) eq 'ARRAY' ? join(',',@{$data{$key}}) : "$data{$key}");
		}
		print "\n";
		exit(1); });

	$data{seed} = ( defined($args{seed}) ? $args{seed} : 0);
	$data{w} = ( defined($args{w}) ? $args{w} : 800);
	$data{h} = ( defined($args{h}) ? $args{h} : 600);
	$data{unit} = ( defined($args{unit}) ? $args{unit} : 50); # scaling number
	$data{scale} = ( defined($args{scale}) ? $args{scale} : 1.1); # scaling number
	$data{hex} = ( defined($args{hex}) ? $args{hex} : 0);
	$data{hexr} = ( defined($args{radius}) ? $args{radius} : 16); # radius of hexagons
	$data{rows} = ( defined($args{rows}) ? $args{rows} : 7);
	$data{cols} = ( defined($args{cols}) ? $args{cols} : $data{rows});
	$data{centype} = ($args{centype} or 0);
	$data{shape} = ( defined($args{shape}) ? $args{shape} : 'hexb');
	$data{hexor} = ( defined($args{hexor}) ? $args{hexor} : 'left');
	$data{pmeth} = ( defined($args{pmeth}) ? $args{pmeth} : 0);
	$data{fillhex} = ( defined($args{hexfillcolor}) ? $args{hexfillcolor} : "#366");
	$data{outhex} = ( defined($args{hexoutlinecolor}) ? $args{hexoutlinecolor} : "#00f");
	$data{joincolor} = ( defined($args{joinfillcolor}) ? $args{joinfillcolor} : "#00f");
	$data{hicolor} = ( defined($args{highwaystroke}) ? $args{highwaystroke} : "#0ff");
	$data{exitn} = ( defined($args{exits}) ? $args{exits} : 5);
	$data{sec} = ( defined($args{sec}) ? $args{sec} : 7);
	$data{ratio} = ( defined($args{ratio}) ? $args{ratio} : 3);
	$data{depth} = ( defined($args{depth}) ? $args{depth} : 3);

	my $steps = $win->NoteBook();
	$steps->pack();

	my $pagesize = $steps->add('siz', -label => "Size/Type");
	my $pagepoi = $steps->add('poi', -label => "POI");
	my $pageexi = $steps->add('exi', -label => "Exits");
	my $pageinr = $steps->add('inr', -label => "Inner Roads");
	my $pageexr = $steps->add('exr', -label => "Outer Roads");
	my $pagesec = $steps->add('sec', -label => "Secondaries");
	my $pagemin = $steps->add('min', -label => "Minor Roads");
	my $pageout = $steps->add('out', -label => "Output");

	$pagesize->Label(-text => "Size and Type of map")->pack;
	$pagepoi->Label(-text => "You may not use this tab until you set a size and type.")->pack;
	$pageexi->Label(-text => "You may not use this tab until all previous tabs have been used.")->pack;
	$pageinr->Label(-text => "You may not use this tab until all previous tabs have been used.")->pack;
	$pageexr->Label(-text => "You may not use this tab until all previous tabs have been used.")->pack;
	$pagesec->Label(-text => "You may not use this tab until all previous tabs have been used.")->pack;
	$pagemin->Label(-text => "You may not use this tab until all previous tabs have been used.")->pack;
	$pageout->Label(-text => "You may not use this tab until all previous tabs have been used.")->pack;

	# Size page
	my $sizerow = $pagesize->Frame()->pack;
	$sizerow->Label(-text => "Width: ")->pack(-side => "left");
	my $wideset = $sizerow->Spinbox(
        qw/-from 300 -to 2000 -width 10 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$data{w} = int($proposed);
		return 1;
	}, -value => $data{w},
    )->pack(-side => "left");
	$sizerow->Label(-text => "Height: ")->pack(-side => "left");
	my $highset = $sizerow->Spinbox(
        qw/-from 200 -to 3000 -width 10 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$data{h} = int($proposed);
		return 1;
	}, -value => $data{h},
    )->pack(-side => "left");
	$pagesize->Label(-text => "(Values may be automatically increased to fit hex grid, if using hexes)")->pack;
	my $hexoptbox = $pagesize->Labelframe(qw/-pady 2 -padx 2/)->pack;
	my $usehex;
	$usehex = $hexoptbox->Checkbutton(
		-text => "Map of hexes",
		-variable => \$data{hex},
		-command => sub { &labelframe_children($hexoptbox,$usehex,\$data{hex})},
		-padx => 0,
		);
	$hexoptbox->configure(-labelwidget => $usehex);

	my $hexshape = $hexoptbox->Menubutton( -text => "Grid shape:", -relief => 'raised',
       )->grid(-row => 0, -column => 0,);

	my @shapes = (
		["Parallelogram",'para'],
		["Triangle (point up)",'trii'],
		["Triangle (point down)",'trid'],
		["Hexagon (rotated cells)",'hexa'],
		["Hexagon (self-similar cells)",'hexb'],
		["Rectangular"=>'rect'],
		);
	my $hshapelabel = $hexoptbox->Label( -text => "Oops" )->grid(-row => 0, -column => 1, -columnspan => 3,);
	my $menu = $hexshape->menu(-tearoff => 0);
	$hexshape->configure(-menu => $menu);
	foreach my $i (0..$#shapes) {
		($data{shape} eq $shapes[$i][1]) && $hshapelabel->configure( -text => $shapes[$i][0] );
	}
	foreach my $i (0..$#shapes) {
		$hexshape->command(-label => "$shapes[$i][0]", -command => sub { $data{shape} = $shapes[$i][1]; $hshapelabel->configure( -text => $shapes[$i][0]); });
	}

	$hexoptbox->Label(-text => "Diagonals/Rows:")->grid(-row => 1, -column => 0);
	$hexoptbox->Spinbox(
        qw/-from 2 -to 100 -width 10 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$data{rows} = int($proposed);
		# Increase screen size if too small
		return 1;
	}, -value => $data{rows},
    )->grid(-row => 1, -column => 1);
	$hexoptbox->Label(-text => "Columns:")->grid(-row => 1, -column => 2);
	$hexoptbox->Spinbox(
        qw/-from 0 -to 100 -width 10 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$data{cols} = int($proposed);
		return 1;
	}, -value => $data{cols},
    )->grid(-row => 1, -column => 3);

	$hexoptbox->Label(-text => "Radius:")->grid(-row => 2, -column => 0);
	$hexoptbox->Spinbox(
        qw/-from 0 -to 100 -width 10 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$data{hexr} = int($proposed);
		return 1;
	}, -value => $data{hexr},
    )->grid(-row => 2, -column => 1);
	#hexorder
	$hexoptbox->Label(-text => "Grid order:")->grid(-row => 2, -column => 2);
	my $horder = $hexoptbox->Spinbox(
        qw/-from 0 -to 5 -width 10 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$proposed = int($proposed);
		($data{shape} == 5) || ($proposed = $proposed % 3); # only rectangle may have order > 2.
		($proposed > 5) && ($proposed = 5);
		($proposed < 0) && ($proposed = 0);
		$data{order} = $proposed;
		return 1;
	}, -value => $data{order},
    )->grid(-row => 2, -column => 3);

	$hexoptbox->Label(-text => "Orientation:")->grid(-row => 3, -column => 0);
	$hexoptbox->Radiobutton( -text => "Flat side", -value => 'left', -variable => \$data{hexor},)->grid(-row => 3, -column => 1);
	$hexoptbox->Radiobutton( -text => "Flat top", -value => 'top', -variable => \$data{hexor},)->grid(-row => 3, -column => 2);

	$hexoptbox->Label(-text => "Fill")->grid(-row => 4,-column => 0);
	my $fillent;
	my $fillpick = $hexoptbox->Menubutton(-relief => 'raised', -indicatoron => 1, -direction => 'below', -borderwidth => 4, -tearoff => 0)->grid(-row => 6, -column => 0);
	$fillent = $hexoptbox->Entry(-width => 7, -text => "$data{fillhex}", -validate => 'focusout', -vcmd => sub { if (validColor($_[0])) { $data{fillhex} = $_[0]; updateSwatch($fillpick,$_[0]); return 1; } else { $fillent->configure(-text => "$data{fillhex}"); return 0; }})->grid(-row => 5, -column => 0);
	colorDrop($fillpick,$fillent);

	$hexoptbox->Label(-text => "Outline")->grid(-row => 4,-column => 1);
	my $outent;
	my $outpick = $hexoptbox->Menubutton(-relief => 'raised', -indicatoron => 1, -direction => 'below', -borderwidth => 4, -tearoff => 0)->grid(-row => 6, -column => 1);
	$outent = $hexoptbox->Entry(-width => 7, -text => "$data{outhex}", -validate => 'focusout', -vcmd => sub { if (validColor($_[0])) { $data{outhex} = $_[0]; updateSwatch($outpick,$_[0]); return 1; } else { $outent->configure(-text => "$data{outhex}"); return 0; }})->grid(-row => 5, -column => 1);
	colorDrop($outpick,$outent);



	labelframe_children($hexoptbox,$usehex,\$data{hex});
	$pagesize->Button(-text => "Continue with\nthese settings",
		-command => sub {
			prepScreen(\%data);
			fillPOI($pagepoi,\%data,$steps);
		})->pack;
	#POI page
	MainLoop();
	exit(0);
}

	# POI page
sub fillPOI {
	my ($page,$data,$nb) = @_;
	emptyFrame($page);
	$nb->raise('poi');
	$page->Label(-text => "Points of Interest / Points of Intersection")->pack;
	my $poitar = $page->Scrolled(qw/Canvas -relief sunken -borderwidth 2 -scrollbars se -scrollregion/ => ['-30c', '-30c', '30c', '30c'],
		-width => $$data{w}, -height => $$data{h});
	my $row = $page->Frame()->pack;
	$row->Label( -text => "Seed:" )->pack(-side => "left");
	my $seedbox = $row->Entry(-text => $$data{seed}, -validate => 'focusout', -validatecommand => sub { $$data{seed} = int($_[0]); print "Seed now $$data{seed}...\n"; 1; } )->pack(-side => "left");
	$row->Button( -text => "Time", -command => sub { $seedbox->delete(0,'end'); $seedbox->insert(0,time()); })->pack(-side => 'left');
	my $column = $page->Frame()->pack(-side => "left");
	$column->Label( -text => "Points:" )->pack;
	$column->Spinbox(
        qw/-from 3 -to 11 -width 3 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$$data{joins} = int($proposed);
		return 1;
	}, -value => $$data{joins},
    )->pack;
	my $ctype = $column->LabFrame( -label => "Center:" )->pack;
	my @centers = ('Central Hub','Starry Ring','Ring','Cluster');
	foreach my $i (0 .. $#centers) {
		$ctype->Radiobutton( -text => "$centers[$i]", -variable => \$$data{centype}, -value => int($i), -justify => 'left', )->pack( -fill => 'x', -expand => 1);
	}
	$column->Label( -text => "Variance:")->pack;
	$$data{variance} = 0.75;
	$column->Entry( -text => "$$data{variance}", -validate => 'key', -vcmd => sub { my $prop = $_[0]; ($prop =~ m/^-?\d*\.?\d+$/) || return 0; $$data{variance} = ($prop * 1.00); return 1; })->pack;
	$$data{waypoints} = [];
	$$data{needed} = 0;
	$column->Label( -text => "Unit:")->pack;
	$column->Entry( -text => $$data{unit}, -validate => 'key', -vcmd => sub { my $prop = $_[0]; ($prop =~ m/^-?\d+$/) || return 0; $$data{unit} = int($prop); return 1; })->pack;
	$$data{unit} = 50;
	$column->Label( -text => "Scale:")->pack;
	$column->Entry( -text => $$data{scale}, -validate => 'key', -vcmd => sub { my $prop = $_[0]; ($prop =~ m/^-?\d*\.?\d+$/) || return 0; $$data{scale} = ($prop * 1.00); return 1; })->pack;
    $poitar->pack(qw/-expand yes -fill both/);

	my $colorbox = $column->Frame()->pack;
	$colorbox->Label(-text => "Joins")->grid(-row => 0,-column => 0);
	my $joinent;
	my $joinpick = $colorbox->Menubutton(-relief => 'raised', -indicatoron => 1, -direction => 'below', -borderwidth => 4, -tearoff => 0)->grid(-row => 1, -column => 0);
	$joinent = $colorbox->Entry(-width => 7, -text => "$$data{joincolor}", -validate => 'focusout', -vcmd => sub { if (validColor($_[0])) { $$data{joincolor} = $_[0]; updateSwatch($joinpick,$_[0]); return 1; } else { $joinent->configure(-text => "$$data{joincolor}"); return 0; }})->grid(-row => 2, -column => 0);
	colorDrop($joinpick,$joinent);

	$colorbox->Label(-text => "Major Roads")->grid(-row => 0,-column => 1);
	my $hiwent;
	my $hiwpick = $colorbox->Menubutton(-relief => 'raised', -indicatoron => 1, -direction => 'below', -borderwidth => 4, -tearoff => 0)->grid(-row => 1, -column => 1);
	$hiwent = $colorbox->Entry(-width => 7, -text => "$$data{hicolor}", -validate => 'focusout', -vcmd => sub { if (validColor($_[0])) { $$data{hicolor} = $_[0]; updateSwatch($hiwpick,$_[0]); return 1; } else { $hiwent->configure(-text => "$$data{hicolor}"); return 0; }})->grid(-row => 2, -column => 1);
	colorDrop($hiwpick,$hiwent);


	my $poioptbox = $column->Labelframe(qw/-pady 2 -padx 2/)->pack;
	my $usepoi;
	$usepoi = $poioptbox->Checkbutton(
		-text => "Use POI generation",
		-variable => \$$data{poi},
		-command => sub { &labelframe_children($poioptbox,$usepoi,\$$data{poi})},
		-padx => 0,
		);
	$poioptbox->configure(-labelwidget => $usepoi);
	my $poimeth = $poioptbox->Menubutton(-relief => 'raised', -text => "Method:")->grid(-row => 0, -column => 0);
	my $poimethodlabel = $poioptbox->Label( -text => "Oops" )->grid(-row => 0, -column => 1, -columnspan => 2);
	$poioptbox->gridRowconfigure(0,-uniform => 'a');
	my $menu = $poimeth->menu(-tearoff => 0);
	$poimeth->configure(-menu => $menu);
	my @methods = ("Weighted Main","Pathway Collapsing","Highway Weighting");
	foreach my $i (0..$#methods) {
		($$data{pmeth} == $i) && $poimethodlabel->configure( -text => $methods[$i] );
	}
	foreach my $i (0..$#methods) {
		$poimeth->command(-label => "$methods[$i]", -command => sub { $$data{pmeth} = $i; $poimethodlabel->configure( -text => $methods[$i]); });
	}

	labelframe_children($poioptbox,$usepoi,\$$data{poi});
	my $confirm;

	$row->Button( -text => "Generate/Update", -command => sub { updateSqs($data,$poitar); $confirm->configure(-state => 'normal'); })->pack(-side => "left");
	$confirm = $row->Button( -text => "Continue with\nthese points ==>", -state => 'disabled', -command => sub { fillExi($nb,$data); } )->pack(-side => "left");
}

	# Exits page
sub fillExi {
	my ($nb,$data) = @_;
	my $page = $nb->page_widget('exi');
	emptyFrame($page);
	$nb->raise('exi');
	$page->Label(-text => "Map Exits")->pack;
	my $exitar = $page->Scrolled(qw/Canvas -relief sunken -borderwidth 2 -scrollbars se -scrollregion/ => ['-30c', '-30c', '30c', '30c'],
		-width => $$data{w}, -height => $$data{h});
	my $row = $page->Frame()->pack;
	my ($map,$scr,@border,%exset,$confirm,$tally,$needent);
	if ($$data{hex}) {
		$map = $$data{grid};
		$scr = $$data{screen};
		@border = $map->genborder(store => 0);
		$$data{border} = \@border;
		foreach my $pair (@border) {
			my $h = Hexagon::Hex->new($$pair[0],$$pair[1]);
			cdHex($exitar,$scr,$h,'white',$$data{outhex},'borhex');
			my $checked = 0;
			my $e;
			$e = $exitar->Checkbutton(-text => "$$pair[0],$$pair[1]", -variable => \$checked, -command => sub {
				$exset{$e->cget('-text')} = $checked;
				print $e->cget('-text') . " " . ($checked ? "" : "un") . "checked!\n";
				updateCount($tally,\%exset);
				checkTotals($tally,$needent,$confirm);
			});
			# TODO: convert hex pair to screen coords
			my $spot = $scr->hex_to_pixel($h);
			$exitar->createWindow($spot->x(),$spot->y(), -window => $e);
		}
	} else {
		Points::setCornerHeadings($$data{w},$$data{h}); # set boundaries for use multiple times.
	}
	my @sqs = @{ $$data{sqs} };
	my @roads = @{ $$data{inroutes} };
	if ($$data{hex}) {
		foreach (@sqs) {
			my $h = $$data{screen}->pixel_to_hex($_,0);
			cdHex($exitar,$$data{screen},$h,$$data{fillhex},$$data{outhex},'join');
		}
	}
	foreach (@roads) {
		cdLine($exitar,$_,$$data{hicolor});
	}
	foreach (@sqs) {
		cdDot($exitar,$_,$$data{joincolor});
	}

	my $row = $page->Frame()->pack;
	$row->Label(-text => "Number of Exits")->pack(-side => 'left');
	$tally = $row->Label(-text => 0, -width => 3)->pack(-side => 'left');
	$row->Label(-text => '/', -width => 1)->pack(-side => 'left');
	$needent = $row->Spinbox(
        qw/-from 1 -to 20 -width 3 -validate key/,
        -validatecommand => sub {
	    my ($proposed, $changes, $current, $index, $type) = @_;
		($proposed =~ m/[^\d]/g) && return 0;
		$$data{exitn} = int($proposed);
		return 1;
	}, -value => $$data{exitn},
    )->pack(-side => 'left');


	$exitar->pack;

	$row->Button(-text => "Auto-select", -command => sub {
		$$data{exits} = [];
		my @exits;
		if ($$data{hex}) {
			@exits = MapDes::pickExitHexes($$data{exitn} - int($tally->cget('-text')),$$data{screen},$$data{grid},$$data{border});
		} else {
			@exits = MapDes::castExits($$data{exitn} - int($tally->cget('-text')),$$data{waypoints},getCenter(),\$$data{numroutes},0);
		}
		$exset{autogen} = scalar @exits;
		$$data{exits} = \@exits;
		updateCount($tally,\%exset);
		checkTotals($tally,$needent,$confirm);
	})->pack(-side => 'left');
	$confirm = $row->Button(-text => "Accept Exits", -state => 'disabled', -command => sub { fillExr($nb,$data,\%exset); })->pack(-side => 'left');
#	$page->Label(-text => "Exits have been chosen. Click 'Accept Exits'.");
}

sub fillExr {
	my ($nb,$data,$exitset) = @_;

}

sub updateCount { # hr is a hashref to a hash of 0/1 values (or ints, I guess)
	my ($obj,$hr) = @_;
	my $total = 0;
	foreach (keys %{$hr}) {
		$total += $$hr{$_};
	}
	my $c = (ref($obj) =~ m/Label/ ? "-text" : "-value");
	$obj->configure($c => $total);
}

sub checkTotals { # cur and need can be a Label or anything with a -value option.
	my ($cur,$need,$object) = @_;
	my $c = (ref($cur) =~ m/Label/ ? "-text" : "-value");
	my $n = (ref($need) =~ m/Label/ ? "-text" : "-value");
	if (int($cur->cget($c)) == int($need->cget($n))) {
		$object->configure(-state => 'normal');
	} else {
		$object->configure(-state => 'disabled');
	}
}

sub updateSqs {
	my ($data,$target) = @_;
	$target->delete('all'); # clear canvas here
print "#";
	srand($$data{seed}); #seeding; this is the only time randomization will reset to seed (for generating the same map).
	my @squares = MapDes::genSquares($$data{joins},$$data{centype},$$data{variance},$$data{waypoints},$$data{needed},\$$data{unit},$$data{scale});
	$$data{sqs} = \@squares;
	my ($numroutes,@waypoints);
	my $i = 0; my @colors = qw/ red orange yellow green SkyBlue2 blue3 violet white black grey /;
	my @irts = MapDes::connectSqs($$data{sqs},\@waypoints,$$data{centype},\$numroutes);
	foreach my $r (@irts) {
		print "Plotting $r->name\n";
		cdArrow($target,$r,$$data{hicolor},'inroute');
	}
	@irts = MapDes::connectSqsHex($$data{screen},\@irts,$$data{grid},color => $$data{hicolor}) if $$data{hex};
	$$data{waypoints} = \@waypoints;
	$$data{numroutes} = $numroutes;
	$$data{inroutes} = \@irts;
	foreach my $s (@squares) {
		# change 0 to 1 in following line for squaregen debug
		my $color = (1 ? $colors[$i % scalar @colors] : $$data{joincolor});
		cdDot($target,$s,$color);
		$i++;
	}

}

# canvas-draw-Functions

sub cdDot {
	my ($target,$p,$color) = @_;
	$target->createOval(
		$p->x - 3,$p->y - 3,$p->x + 3,$p->y + 3,
		-fill => $color,
		qw/-tags points/);
}

sub cdArrow {
	my ($target,$s,$color,$tag) = @_;
	$target->createLine(
		$s->ox,$s->oy,$s->ex,$s->ey,
		-arrow => 'last',
		-fill => $color,
		-tags => $tag);
}

sub cdLine {
	my ($target,$s,$color,$tag) = @_;
	$target->createLine(
		$s->ox,$s->oy,$s->ex,$s->ey,
		-fill => $color,
		-tags => $tag);
}

sub cdHex {
	my ($target,$scr,$h,$color,$ocolor,$tag) = @_;
	my @corners = $scr->polygon_corners($h);
	my @points;
	foreach (@corners) {
		push(@points,$_->x(),$_->y());
	}
	$target->createPolygon(
		@points,
		-fill => $color,
		-outline => $ocolor,
		-tags => $tag);
}

sub prepScreen {
	my ($data) = @_;
	my @boxen;
	my ($width,$height,$cx,$cy) = ($$data{w} or 800,$$data{h} or 600,0,0);
	($cx,$cy) = (int($width/2),int($height/2));
	if ($$data{hex}) {
		my ($sca,$w,$h,$order,$shape,$orient) = ($$data{hexr},$$data{rows},$$data{cols},$$data{order},$$data{shape},$$data{hexor});
		my $g = Hexagon::Map->new($shape,$order,$w,$h);
		$width = max($width,$sca * $g->width() + 14); # minimum sizes plus a little border
		$height = max($height,abs($sca) * $g->height() + 14); # TODO: check this with all grid shapes and adjust, if necessary.
		($cx,$cy) = (int($width/2),int($height/2));
		my $scr = Hexagon::Screen->new($orient,$sca,$sca,$g->req_offset($sca),$cx,$cy);
		if (1) {
			$scr->{debug} = 1;
			my $ch = int($w/2);
			$g->addCenter("#f0f");
#			$$data{center} = $g->add_hex_at($ch,$ch,fill => "#f00");
		}
		$$data{grid} = $g;
		$$data{screen} = $scr;
	}
	$$data{w} = $width;
	$$data{h} = $height;
	push(@boxen,{ 'w' => $width, 'h' => $height, 'f'=> '#fff', 'x' => 0, 'y' => 0 });
	$$data{boxen} = \@boxen;

	MapDes::setMDConf("width",$width,"height",$height);
	MapDes::setMDConf("centerx",$cx,"centery",$cy);



}

sub emptyFrame {
	my ($container) = @_;
	foreach ($container->children) {
		$_->destroy();
	}
}

sub colorDrop {
	my ($button,$target) = @_;
	my $p = $button->Photo(-width => 16, -height => 16);
	$p->put($target->cget('-text'), qw/	-to 0 0 15 15/);
	$button->configure(-image => $p);
	my @colors = qw( LightGrey Red Green Yellow Blue Purple Cyan LightRed LightGreen LightYellow LightBlue Pink LightCyan White Gray Orange );
	my @values = qw( cccccc ff0000 00ff00 ffff00 00f 909	33ffff ff6666 66ff66 ffff99			66f ff99ff 99ffff ffffff 808080 ff9900);
	my $menu = $button->cget('-menu');
	foreach my $i (0..$#colors) {
		my $mi = $button->Photo(-width => 16, -height => 16);
		my $color = "#$values[$i]";
		$mi->put($color, qw/	-to 0 0 15 15/);
		$menu->radiobutton(
			-label => $colors[$i],
			-compound => 'left',
			-image => $mi,
			-command => sub { $target->configure(-text => $color); $target->validate(); },
		);
		$menu->entryconfigure($colors[$i], -columnbreak => 1) unless $i % 4;
	}
}

sub updateSwatch {
	my ($mb,$color) = @_;
	my $p = $mb->Photo(-width => 16, -height => 16);
	$p->put($color, qw/	-to 0 0 15 15/);
	$mb->configure(-image => $p);
}

sub validColor {
	my ($prop) = @_;
	return ($prop =~ m/^#[0-9a-fA-f]{3}$/ or $prop =~ m/^#[0-9a-fA-f]{6}$/);
}

sub item_drag { # copy/paste from widget to get item dragging
	my ($c,$id,$var) = @_; # get canvas
	$c->bind($id,'<ButtonPress-1>' =>
		[sub {
			my ($canv,$id) = @_;
			my ($x,$y) = ($Tk::event->x,$Tk::event->y);
			($canv->{'x' . $id}, $canv->{'y' . $id}) = ($x,$y);
		},$id]);
	$c->bind($id,'<ButtonRelease-1>' =>
		[sub {
			my ($canv,$id) = @_;
			my ($x,$y) = ($Tk::event->x,$Tk::event->y);
			$var->move($x,$y); # set $var x/y to x/y
			$c->move($id,$x - $canv->{'x' . $id},$y - $canv->{'y' . $id});
		},$id]);
} # end items_drag

1;
