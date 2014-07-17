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
    my ($w,$h,$linesr,$boxr) = @_;
    my @lines = @$linesr;
    # declare SVG document type:
#    my $out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 20000303 Stylable//EN\" \"http://www.w3.org/TR/2000/03/WD-SVG-20000303/DTD/svg-20000303-stylable.dtd\">\n";
    my $out = "<?xml version=\"1.0\" standalone=\"no\"?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n";
    $out = "$out<svg width=\"100%\" height=\"100%\" version=\"1.0\" xmlns=\"http://w3.org/2000/svg\">\n";
	$out = "$out    <rect height=\"$h\" width=\"$w\" fill=\"#fff\" />\n";
    foreach my $i (0 .. $#lines) {
        my $line = $lines[$i];
        my $curcol = incColor(); # later, do this only when switching road types, or not at all.
        $out = "$out    <line x1=\"" . $line->ox() . "\" y1=\"" . $line->oy() . "\" x2=\"" . $line->ex() . "\" y2=\"" . $line->ey() . "\" stroke=\"$curcol\" />\n";
    }
    $out = "$out</svg>\n";
    return $out; 
}

sub saveSVG {
    my ($data,$filename) = @_;
	print "Writing SVG to '$filename'...";
    open (OUTFILE, ">$filename") || return (-1,$!);
    print OUTFILE $data;
    return 0;
}

1;