package Points;
use Math::Trig qw( atan pi );
use Math::Round qw( round );
use List::Util qw( min );

sub findOnLine {
    my ($x1,$y1,$x2,$y2,$frac) = @_;
    my $dx = abs($x1 - $x2);
    my $dy = abs($y1 - $y2);
    my @p;
    $p[0] = min($x1,$x2) + ($dx * $frac);
    $p[1] = min($y1,$y2) + ($dy * $frac);
    return @p;
}

sub perpDist {
    my ($x0,$y0,$x1,$y1,$x2,$y2) = @_; # point, line start, line end
    my $dx = abs($x1 - $x2);
    my $dy = abs($y1 - $y2);
    my $d = (abs($dy*$x0 - $dx*$y0 - $x1*$y2 + $x2*$y1) / sqrt($dx^2 + $dy^2));
    return $d;
}

sub choosePointAtDist {
    my ($x,$y,$dist,$min,$max,$offset) = @_; ## center/origin x,y; length of line segment; min,max bearing of line; bearing offset
    my $bearing = rand($max - $min) + $min + $offset;
    return getPointAtDist($x,$y,$dist,$bearing);
}

sub getPointAtDist {
    my ($x,$y,$d,$b) = @_; ## center/origin x,y; length of line segment; bearing of line segment
    my @p;
    $p[0] = $x + (cos($b) * $d);
    $p[1] = $y + (sin($b) * $d);
    return @p;
}

sub chooseAHeading {
    my ($offset,$whole) = @_;
    my $bearing = rand(80) + 5 + $offset;
    return $bearing;
}

sub getAHeading {
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