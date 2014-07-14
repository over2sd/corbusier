use strict;

package Points;
use Math::Trig qw( atan pi );
use Math::Round qw( round );
use List::Util qw( min );

my $debug = 1;

sub pointIsOnLine {
    if ($debug) { print "pointIsOnLine(@_)\n"; }
    my ($x0,$y0,$x1,$y1,$x2,$y2,$fuzziness) = @_; # point, line start, line end
    my $det = ($x2 - $x1) * ($y0 - $y1) - ($y2 - $y1) * ($x0 - $x1);
    return (abs($det) < $fuzziness);
}

sub findOnLine {
    if ($debug) { print "findOnLine(@_)\n"; }
    my ($x1,$y1,$x2,$y2,$frac) = @_;
    my $dx = abs($x1 - $x2);
    my $dy = abs($y1 - $y2);
    my @p;
    $p[0] = min($x1,$x2) + ($dx * $frac);
    $p[1] = min($y1,$y2) + ($dy * $frac);
    return @p;
}

sub getDist {
    if ($debug) { print "getDist(@_)\n"; }
    my ($x1,$y1,$x2,$y2,$sides) = @_; # point 1, point 2, return all distances?
    my $dx = $x1 - $x2; # preserving sign for rise/run
    my $dy = $y1 - $y2;
    my $d = sqrt($dx^2 + $dy^2); # squaring makes values absolute
    if ($sides) { return $d,$dy,$dx; } # dist, rise, run
    return $d;
}

sub getClosest {
    if ($debug) { print "getClosest(@_)\n"; }
    my ($ox,$oy,$ex,$ey,@ptlist) = @_;
    my $lowdex = 0;
    my $lowdist = undef;
    foreach my $i (0 .. $#ptlist) {
        my $d = getDist($ptlist[$i][0],$ptlist[$i][1],$ox,$oy,0);
        if ($ptlist[$i][0] == $ex and $ptlist[$i][1] == $ey) {
            # do nothing  # point is the excluded point
        } elsif (not defined $lowdist or $d < $lowdist) {
            $lowdist = $d;
            $lowdex = $i;
        }
    }
    return $lowdex;
}

sub perpDist { # Algorithm source: Wikipedia/Distance_from_a_point_to_a_line
    if ($debug) { print "perpDist(@_)\n"; }
    my ($x0,$y0,$x1,$y1,$x2,$y2) = @_; # point, line start, line end
    my $dx = abs($x1 - $x2);
    my $dy = abs($y1 - $y2);
    my $d = (abs($dy*$x0 - $dx*$y0 - $x1*$y2 + $x2*$y1) / sqrt($dx^2 + $dy^2));
    return $d;
}

sub choosePointAtDist {
    if ($debug) { print "choosePointAtDist(@_)\n"; }
    my ($x,$y,$dist,$min,$max,$offset) = @_; ## center/origin x,y; length of line segment; min,max bearing of line; bearing offset
    my $bearing = rand($max - $min) + $min + $offset;
    return getPointAtDist($x,$y,$dist,$bearing);
}

sub getPointAtDist {
    if ($debug) { print "getPointAtDist(@_)\n"; }
    my ($x,$y,$d,$b) = @_; ## center/origin x,y; length of line segment; bearing of line segment
    my @p;
    $p[0] = $x + (cos($b) * $d);
    $p[1] = $y + (sin($b) * $d);
    return @p;
}

sub chooseAHeading {
    if ($debug) { print "chooseAHeading(@_)\n"; }
    my ($offset,$whole) = @_;
    my $bearing = rand(80) + 5 + $offset;
    return $bearing;
}

sub getAHeading {
    if ($debug) { print "getAHeading(@_)\n"; }
    my ($dx,$dy,$offset,$whole) = @_;
    if (not defined $whole) { $whole = 0; }
    my $h = atan($dx,$dy)*180/pi;
    $h = $h + ($offset or 0);
    if ($whole) {
        $h = round($h)
    }
    if ($h < -180) {
        $h += 360;
    } elsif ($h > 180) {
        $h -= 360;
    }
    return $h;
}

1;