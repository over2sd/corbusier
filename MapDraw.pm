package MapDraw;

use strict;
use warnings;

my %color = ( 'r' => 0, 'g' => 0, 'b' => 0 );

sub getColor {
    return sprintf("#%02x%02x%02x",$color{'r'}, $color{'g'}, $color{'b'});
}

sub incColor {
    my $curcol = getColor();
    $color{'b'} += 51;
    if ($color{'b'} > 255) {
        $color{'b'} = 0;
        $color{'g'} += 51;
        if ($color{'g'} > 255) {
            $color{'g'} = 0;
            $color{'r'} += 51;
            if ($color{'r'} > 255) {
                $color{'r'} = 0;
                # blue should already be 0 to get here.
            }
        }
    }
    return $curcol;
}

sub formSVG {
	print "Forming SVG...";
    my ($w,$h,$linesr,$boxr,%exargs) = @_;
	my ($offsetx,$offsety,$showseed,$seed) = (0,0,0,0);
	if (defined $exargs{'seed'}) {
		$seed = $exargs{'seed'};
		$showseed = 1;
	}
	if (defined $exargs{'xoff'}) {
		$offsetx = $exargs{'xoff'};
	}
	if (defined $exargs{'yoff'}) {
		$offsety = $exargs{'yoff'};
	}
    my @lines = @$linesr;
	my $out = "";
	foreach my $br (@{ $boxr }) {
		my %box = %$br;
		$out = sprintf("$out	<rect x=\"%d\" y=\"%d\" height=\"%d\" width=\"%d\" fill=\"%s\" />\n",$box{'x'} + $offsetx,$box{'y'} + $offsety,$box{'h'},$box{'w'},$box{'f'});
	}
    my $curcol = incColor(); # later, do this only when switching road types, or not at all.
    foreach my $i (0 .. $#lines) {
        my $line = $lines[$i];
		$curcol = $line->getMeta("color");
		unless (defined $curcol) { $curcol = ($line->can_move() ? "#600" : "#36F"); }
        $out = sprintf("$out	<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"$curcol\" />\n",$line->ox() + $offsetx,$line->oy() + $offsety,$line->ex() + $offsetx,$line->ey() + $offsety);
    }
	if ($showseed) {
		my $boxw = 160;
		$out = sprintf("$out	<rect x=\"%d\" y=\"%d\" width=\"$boxw\" height=\"40\" fill=\"#6ff\" />\n	<text x=\"%d\" y=\"%d\" font-size=\"3.2em\" fill=\"#00c\">#$seed</text>\n",$offsetx + $w - $boxw,$offsety,$offsetx + $w - $boxw + 5,$offsety + 35);
	}
    return $out; 
}

sub formGrid {
    print "Adding grid...";
    my ($out,$grid,%exargs) = @_;
    my %gridobs = %{ $grid->{grid} };
    my $coords = ($exargs{showcoord} or 0);
    my $offsetx = ($exargs{offsetx} or 0);
    my $offsety = ($exargs{offsety} or 0);
    foreach (keys %gridobs) {
	my $ob = $gridobs{$_};
#print "\n'$_' forming object " . $ob->Iama . " at " . $ob->loc . "...";
	my $scr = Hexagon::Screen->new('left',15,15,30,20);
	my @pointlist = $scr->hex_to_poly($ob);
	my $points = "";
	my ($r,$g,$b) = (255,255,255);
	$r = ($ob->q < 0 ? 51 : $ob->q * 16 % 200 + 52);
	$g = ($ob->r < 0 ? 51 : $ob->r * 16 % 200 + 52);
	$b = ($ob->s < 0 ? 51 : $ob->s * 16 % 200 + 52);
	my $fill = ($ob->name =~ m/^#/ ? $ob->name : sprintf("#%x%x%x",$r,$g,$b));
	foreach (0 .. $#pointlist) {
	    unless ($_ == 0) { $points = "$points "; }
	    my $v = $pointlist[$_];
	    $points = sprintf("%s%.3f,%.3f ",$points,$v->x + $offsetx,$v->y + $offsety);
	}
	my ($x,$y) = ($pointlist[2]->x + $offsetx + 7,$pointlist[2]->y + $offsety);
	my $text = $ob->{text};
	$out = sprintf("$out	<polygon points=\"%s\" style=\"fill:%s;stroke:#000;\" />\n",$points,$fill);
	($text ne "") && ($out = sprintf("$out	<text x=\"%d\" y=\"%d\" font-size=\"0.8em\" fill=\"#00c\">%s</text>\n",$x,$y - 7,$text));
    }
    return $out;
}

sub saveSVG {
    my ($data,$filename) = @_;
	print "Writing SVG to '$filename'...";
    # declare SVG document type:
#    my $out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 20000303 Stylable//EN\" \"http://www.w3.org/TR/2000/03/WD-SVG-20000303/DTD/svg-20000303-stylable.dtd\">\n";
    my $out = "<?xml version=\"1.0\" standalone=\"no\"?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n";
    $out = "$out<svg width=\"100%\" height=\"100%\" version=\"1.0\" xmlns=\"http://w3.org/2000/svg\">\n";
    $out = "$out$data</svg>\n";
    open (OUTFILE, ">$filename") || return (-1,$!);
    print OUTFILE $out;
    return 0;
}

1;
