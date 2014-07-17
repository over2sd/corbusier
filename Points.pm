use warnings;
use strict;
############################ Vertex (point) Library ############################
package Vertex;

sub new {
	my ($class,$i,$n,$x1,$y1,$z1) = @_;
	my $self = {
        identity => ($i or 0),
        moniker => ($n or 'Unnamed'),
        origin_x => ($x1 or 0),
        origin_y => ($y1 or 0),
        origin_z => ($z1 or 0),
        immobile => 0
	};
	bless $self,$class;
	return $self;
}

sub id {
	my ($self,$value) = @_;
	$self->{identity} = $value if defined($value);
	return $self->{identity};
}

sub name {
	my ($self,$value) = @_;
	$self->{moniker} = $value if defined($value);
	return $self->{moniker};
}

sub x {
	my ($self,$value) = @_;
	$self->{origin_x} = $value if (defined($value) and not $self->{immobile});
	return $self->{origin_x};
}

sub y {
	my ($self,$value) = @_;
	$self->{origin_y} = $value if (defined($value) and not $self->{immobile});
	return $self->{origin_y};
}

sub z {
	my ($self,$value) = @_;
	$self->{origin_z} = $value if (defined($value) and not $self->{immobile});
	return $self->{origin_z};
}

sub move {
	my ($self,$x,$y,$z) = @_;
    if ($self->{immobile}) {
        warn "Trying to move immobile vertex $self";
        return 86;
    }
    if (not defined $x or not defined $y) { return 1; }
    $self->{origin_x} = $x;
    $self->{origin_y} = $y;
    if (defined $z) { $self->{origin_z} = $z; }
    return 0;
}

sub can_move {
	my ($self,$value) = @_;
	if (defined $value) {
        $self->{immobile} = ($value == 0 ? 1 : 0);
    }
    if ($self->{immobile}) { return 0; }
	return 1;
}

sub immobilize {
	my $self = shift;
	$self->{immobile} = 1;
	return 0;
}

sub describe {
    my ($self,$vv,$showz) = @_;
    unless (defined $vv) { $vv = 0 };
    if ($vv == 0) { return $self->x(),$self->y(),$self->z(); } # 0
    my $bio = "I am a" . ( $self->can_move() ? " " : "n im") . "movable point from (" . $self->x() . "," . $self->y() . ($showz ? "," . $self->z() : "" ) . ")."; # 1
    return $bio;
}

############################### Segment Library ################################
package Segment;

sub new {
	my ($class,$i,$n,$x1,$x2,$y1,$y2,$z1,$z2) = @_; # needs ID;
	my $self = {
        identity => ($i or 0),
        moniker => ($n or 'Unnamed'),
        origin_x => ($x1 or 0),
        origin_y => ($y1 or 0),
        origin_z => ($z1 or 0),
        distance_x => 0,
        distance_y => 0,
        distance_z => 0,
        immobile => 0
	};
	bless $self,$class;
    $self->move_endpoint($x2,$y2,$z2);
	return $self;
}

sub id {
	my ($self,$value) = @_;
	$self->{identity} = $value if defined($value);
	return $self->{identity};
}

sub name {
	my ($self,$value) = @_;
	$self->{moniker} = $value if defined($value);
	return $self->{moniker};
}

sub slope {
    my $self = shift;
    if ($self->{distance_x} == 0) { return undef; } # vertical line, even if length of line is 0, for the sake of simplicity and consistency in the program.
    if ($self->{distance_y} == 0) { return 0; } # horizontal line
    return $self->{distance_y} / $self->{distance_x};
}

sub y_intercept {
    my $self = shift;
    my $m = $self->slope();
    if (not defined $m) { return $self->{origin_x}; } # undefined slope == vertical line.
    my $b = $self->{origin_y} - ($m * $self->{origin_x});
    return $b;
}

sub ox {
	my ($self,$value) = @_;
	$self->{origin_x} = $value if (defined($value) and not $self->{immobile});
	return $self->{origin_x};
}

sub oy {
	my ($self,$value) = @_;
	$self->{origin_y} = $value if (defined($value) and not $self->{immobile});
	return $self->{origin_y};
}

sub oz {
	my ($self,$value) = @_;
	$self->{origin_z} = $value if (defined($value) and not $self->{immobile});
	return $self->{origin_z};
}

sub xl {
	my ($self,$value) = @_;
	$self->{distance_x} = $value if (defined($value) and not $self->{immobile});
	return $self->{distance_x};
}

sub yl {
	my ($self,$value) = @_;
	$self->{distance_y} = $value if (defined($value) and not $self->{immobile});
	return $self->{distance_y};
}

sub zl {
	my ($self,$value) = @_;
	$self->{distance_z} = $value if (defined($value) and not $self->{immobile});
	return $self->{distance_z};
}

sub ex {
    my $self = shift;
    return $self->{origin_x} + $self->{distance_x};
}

sub ey {
    my $self = shift;
    return $self->{origin_y} + $self->{distance_y};
}

sub ez {
    my $self = shift;
    return $self->{origin_z} + $self->{distance_z};
}

sub move {
	my ($self,$x,$y,$z) = @_;
    if ($self->{immobile}) {
        warn "Trying to move immobile line $self";
        return 86;
    }
    if (not defined $x or not defined $y) { return 1; }
    $self->{origin_x} = $x;
    $self->{origin_y} = $y;
    if (defined $z) { $self->{origin_z} = $z; }
    return 0;
}

sub move_endpoint {
	my ($self,$x,$y,$z) = @_;
    if ($self->{immobile}) {
        warn "Trying to move immobile line $self";
        return 86;
    }
    if (not defined $x or not defined $y) { return 1; }
	$self->{distance_x} = 0 + $x - $self->{origin_x};
	$self->{distance_y} = 0 + $y - $self->{origin_y};
    if (defined $z) { $self->{distance_z} = 0 + $z - $self->{origin_z}; }
	return 0;
}

sub move_origin_only {
	my ($self,$x,$y,$z) = @_;
    if ($self->{immobile}) {
        warn "Trying to move immobile line $self";
        return 86;
    }
    if (not defined $x or not defined $y) { return 1; }
    my @end = $self->ex(),$self->ey(),$self->ez();
    $self->{origin_x} = $x;
    $self->{origin_y} = $y;
    if (defined $z) { $self->{distance_z} = $z; }
    my $a = $self->move_endpoint($end[0],$end[1],$end[2]);
    if ($a) { return 2; }
    return 0;
}

sub can_move {
	my ($self,$value) = @_;
	if (defined $value) {
        $self->{immobile} = ($value == 0 ? 1 : 0);
    }
    if ($self->{immobile}) { return 0; }
	return 1;
}

sub immobilize {
	my $self = shift;
	$self->{immobile} = 1;
	return 0;
}

sub set_ends {
    my ($self,$x1,$x2,$y1,$y2,$z1,$z2) = @_;
    if ($self->{immobile}) {
        warn "Trying to move immobile line $self";
        return 86;
    }
    if (not defined $x1 or not defined $y1 or not defined $x2 or not defined $y2) { return -1; }
    my $rv = 0;
    $rv += $self->move($x1,$y1,$z1);
    $rv += $self->move_endpoint($x2,$y2,$z2);
    return $rv;
}

sub describe {
    my ($self,$vv,$showz) = @_;
    unless (defined $vv) { $vv = 0 };
    if ($vv == 0) { return $self->ox(),$self->oy(),$self->oz(),$self->ex(),$self->ey(),$self->ez(); } # 0
    my $bio = "I am a" . ( $self->can_move() ? " " : "n im") . "movable line segment from (" . $self->ox() . "," . $self->oy() . ($showz ? "," . $self->oz() : "" ) . ") to (" .  $self->ex() . "," . $self->ey() . ($showz ? "," . $self->oz() : "" ) . ")."; # 1
    if ($vv > 1) { $bio = "$bio I have a slope of " . $self->slope() . "."; # 2
        if ($vv > 2) { $bio = "$bio If I am long enough in the right direction, I cross 0 at " . $self->y_intercept() . "."; # 3
            if ($vv > 3) {
                $bio = "$bio My length is " . Points::getDist($self->ox(),$self->oy(),$self->ex(),$self->ey()) . "."; # 4
            }
        }
    }
    return $bio;
}

############################### Points Library #################################
package Points;
use Math::Trig qw( atan pi );
use Math::Round qw( round );
use List::Util qw( min );

my $debug = 1;

sub pointIsOnLine { # Don't remember the source of this algorithm, but it was given as a formula.
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
    if ($debug > 1) { print "getDist(@_)\n"; }
    my ($x1,$y1,$x2,$y2,$sides) = @_; # point 1, point 2, return all distances?
    my $dx = $x1 - $x2; # preserving sign for rise/run
    my $dy = $y1 - $y2;
    my $d = sqrt($dx**2 + $dy**2); # squaring makes values absolute
	if ($debug > 1) { print "In: $x1,$y1 - $x2,$y2 -- $dy/$dx :: $d\n"; }
    if ($sides) { return $d,$dy,$dx; } # dist, rise, run
    return $d;
}

sub getClosest {
   if ($debug > 1) { print "getClosest(@_)\n"; }
    my ($ox,$oy,$ptlr,%exargs) = @_; # origin, excluded point, list of vertices
	my @ptlist = @$ptlr;
	my $ex; my $ey;
	if (defined $exargs{'exclude'}) {
		my $xv = $exargs{'exclude'};
		$ex = $xv->x();
		$ey = $xv->y();
	}
    my $lowdex = 0;
    my $lowdist = undef;
    foreach my $i (0 .. $#ptlist) {
        my ($d,$dy,$dx) = getDist($ptlist[$i]->x(),$ptlist[$i]->y(),$ox,$oy,1);
        if (defined $ex and defined $ey and $ptlist[$i]->x() == $ex and $ptlist[$i]->y() == $ey) {
            # do nothing  # point is the excluded point
        } elsif (not defined $lowdist or $d < $lowdist) {
			print "Low: " . (defined $lowdist ? $lowdist : "undef") . "(#$lowdex) => $d (#$i) - - - $dy/$dx\n";
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
    my $d = (abs($dy*$x0 - $dx*$y0 - $x1*$y2 + $x2*$y1) / sqrt($dx**2 + $dy**2));
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

sub closestCardinal {
	my ($x,$y,$w,$h) = @_; # point, w/h of field
	if (not defined $h or not defined $w or not defined $y or not defined $x) { warn "closestCardinal takes 4 arguments: x,y,width,height"; return -1; }
	my @trials = (Vertex->new(0,'',int($w/2),0),Vertex->new(0,'',$w,0),Vertex->new(0,'',$w,int($h/2)),Vertex->new(0,'',$w,$h),Vertex->new(0,'',int($w/2),$h),Vertex->new(0,'',0,$h),Vertex->new(0,'',0,int($h/2)),Vertex->new(0,'',0,0));
	my $d;
	my $cd = -2;
	foreach my $i (0 .. 7) {
		my $id = getDist($trials[$i]->x(),$trials[$i]->y(),$x,$y);
		if (not defined $d or $id < $d) {
			$cd = $i; $d = $id;
		} elsif ($id == $d) {
			if (int(rand(2))) { if ($debug) { print "Replacing"; }} else { $cd = $i; }; # randomly decide whether to replace equivalent values.
		}
	}
	return $cd; # returns a cardinal direction, clockwise from 0 (N or top) to 7 (NW or topleft)
}

1;