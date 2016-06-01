package MapDraw;

use strict;
use warnings;

my %color = ( 'r' => 0, 'g' => 0, 'b' => 0 );
my @layers;

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

sub formLayerObject {
	my ($layer,$obtype,$objects,%exargs) = @_;
	unless ($#layers >= $layer) { foreach (scalar @layers .. $layer) { $layers[$_] = [];}};
	# form SVG as usual
	my $out = "";
	(defined $exargs{'xoff'}) || ($exargs{'xoff'} = 0);
	(defined $exargs{'yoff'}) || ($exargs{'yoff'} = 0);
	for ($obtype) {
		if (/box/) {
			foreach my $br (@{ $objects }) {
				my %box = %$br;
				$out = sprintf("$out	<rect x=\"%d\" y=\"%d\" height=\"%d\" width=\"%d\" fill=\"%s\" />\n",$box{'x'} + $exargs{'xoff'},$box{'y'} + $exargs{'yoff'},$box{'h'},$box{'w'},$box{'f'});
			}
		} elsif (/cir/) {
			foreach my $cr (@{ $objects }) {
				my %c = %$cr;
				$out = sprintf("$out	<circle cx=\"%d\" cy=\"%d\" r=\"%d\" fill=\"%s\" stroke=\"%s\" />\n",($c{x} + ($c{xoff} or 0)),($c{y} + ($c{yoff} or 0)),$c{r},($c{fill} or 'none'),($c{stroke} or "#000"));
			}
		} elsif (/pol/) {
			foreach my $points (@$objects) {
				my ($x,$y) = (($exargs{x} or 0),($exargs{y} or 0));
				$out = sprintf("$out	<polygon points=\"%s\" style=\"fill:%s;stroke:#000;\" />\n",$points,$exargs{fill});
				($exargs{coords} && defined $exargs{loc}) && ($out = sprintf("$out	<text x=\"%d\" y=\"%d\" font-size=\"0.8em\" fill=\"#00c\">%s</text>\n",$x,$y,$exargs{loc}));
				($exargs{text} && $exargs{text} ne "") && ($out = sprintf("$out	<text x=\"%d\" y=\"%d\" font-size=\"0.8em\" fill=\"#00c\">%s</text>\n",$x,$y,$exargs{text}));
			}
		} elsif (/lin/) {
			my @lines = @$objects;
			foreach my $i (0 .. $#lines) {
				my $line = $lines[$i];
				my $curcol = $line->getMeta("color");
				unless (defined $curcol) { $curcol = ($line->can_move() ? "#600" : "#36F"); }
				$out = sprintf("$out	<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"$curcol\" />\n",$line->ox() + $exargs{xoff},$line->oy() + $exargs{yoff},$line->ex() + $exargs{xoff},$line->ey() + $exargs{yoff});
			}
		} elsif (/seed/) {
			my $boxw = $$objects[0];
			my $seed = $$objects[2];
			$out = sprintf("$out	<rect x=\"%d\" y=\"%d\" width=\"$boxw\" height=\"40\" fill=\"#6ff\" />\n	<text x=\"%d\" y=\"%d\" font-size=\"3.2em\" fill=\"#00c\">#$seed</text>\n",$exargs{xoff} + $$objects[1] - $boxw,$exargs{yoff},$exargs{xoff} + $$objects[1] - $boxw + 5,$exargs{yoff} + 35);
		} elsif (/text/) {
			$out = sprintf("$out	<text x=\"%d\" y=\"%d\" font-size=\"1.0em\" fill=\"%s\">%s</text>\n",$exargs{xoff} + 5,$exargs{yoff} + 35,$$objects[1],$$objects[0]);
		}
	}
	# store SVG in layer.
	unless ($obtype =~ /poly/ || scalar @$objects < 2) { print "Storing $obtype (x" . scalar @$objects . ") in layer $layer..."; }
	push(@{ $layers[$layer] },$out);
}

sub getSVGLayers {
	my ($layer) = @_;
	(defined $layer) && return $layers[$layer];
	my $svg = "";
	foreach my $i (0 .. $#layers) {
		foreach my $j (0 .. $#{ $layers[$i] }) {
			$svg = "$svg$layers[$i][$j]";
		}
	}
	return $svg;
}

sub formSVG {
	print "Forming SVG...";
    my ($w,$h,$linesr,$boxr,%exargs) = @_;
	my ($offsetx,$offsety,$showseed,$seed) = (0,0,0,0);
	if (defined $exargs{'seed'}) {
		$seed = $exargs{'seed'};
		$showseed = 1;
	}
	(defined $exargs{'xoff'}) || ($exargs{'xoff'} = $offsetx);
	(defined $exargs{'yoff'}) || ($exargs{'yoff'} = $offsety);
	formLayerObject(0,'boxes',$boxr,%exargs);
	if (defined $exargs{'grid'} and defined $exargs{'screen'}) {
#		$exargs{'center'} = [$w/2,$h/2];
		$exargs{fill} = "#6f6";
		formGrid($exargs{'screen'},$exargs{'grid'},%exargs); # layer 1
	}
    my $curcol = incColor(); # later, do this only when switching road types, or not at all.
	formLayerObject(3,'lines',$linesr,%exargs); # layer 2 is used by HexMap for POI, so this is layer 3.
	if ($showseed) {
		formLayerObject(4,'seed',[160,$w,$seed],%exargs);
	}
}

sub pointify {
	my ($screen,$hex,$offx,$offy) = @_;
	my @pointlist = $screen->hex_to_poly($hex);
	my $points = "";
	my ($r,$g,$b) = (255,255,255);
	$r = ($hex->q < 0 ? 51 : $hex->q * 16 % 200 + 52);
	$g = ($hex->r < 0 ? 51 : $hex->r * 16 % 200 + 52);
	$b = ($hex->s < 0 ? 51 : $hex->s * 16 % 200 + 52);
	my $fill = ($hex->fill =~ m/^#/ || $hex->fill eq 'none' ? $hex->fill : sprintf("#%x%x%x",$r,$g,$b));
    $offx -= 0; # 255
    $offy += 0; # 138
	foreach (0 .. $#pointlist) {
		unless ($_ == 0) { $points = "$points "; }
		my $v = $pointlist[$_];
		$points = sprintf("%s%d,%d ",$points,$v->x + $offx,$v->y + $offy);
	}
	# text location, near point 3 of the hex:
	my ($x,$y) = (int(($pointlist[2]->x or 0) + $offx + 3.5),int(($pointlist[2]->y or 0) + $offy - 3.5));
$screen->{debug} = 0;
	return ($points,$x,$y,$fill);
}

sub formGrid {
    print "Adding grid...";
    my ($scr,$grid,%exargs) = @_;
    my %gridobs = %{ $grid->{grid} };
    my $coords = ($exargs{showcoord} or 0);
    my $offsetx = ($exargs{xoff} or 0);
    my $offsety = ($exargs{yoff} or 0);
    my $mult = $grid->{width};

# test stuff
    my $center = ($exargs{center} or [$scr->sx * $mult,$scr->sy * $mult]);
print "Center: " . join(',',@$center) . " Offset: $offsetx,$offsety =>";
	my $hor = Segment->new(undef,'horiz',$$center[0] + $offsetx,$$center[0] + $offsetx,0 + $offsety,$$center[1] * 2 + $offsety);
	my $ver = Segment->new(undef,'vert',0 + $offsetx,$$center[0] * 2 + $offsetx,$$center[1] + $offsety,$$center[1] + $offsety);
	formLayerObject(1,'lines',[$hor,$ver]);
# test stuff ends

    foreach (keys %gridobs) {
		my $ob = $gridobs{$_};
#print "\n'$_' forming object " . $ob->Iama . " at " . $ob->loc . "...";
		my ($points,$x,$y,$fill) = pointify($scr,$ob,$offsetx,$offsety,($ob->fill or undef));
		my $text = $ob->{text};
		my $loc = $ob->loc;
		formLayerObject(1,'polygon',[$points,],x => $x,y => $y, text => $text, coords => $coords, fill => $fill,loc => $loc);
    }
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
