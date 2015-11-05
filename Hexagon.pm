# Hexagon library
# based on http://www.redblobgames.com/grids/hexagons/implementation.html
use strict;
use warnings;

package Hexagon;

sub placeHex {
	my ($order,$x,$y,%profile) = @_;
	my $h;
	for ($order) { # order is 0: (q,r), 1: (s,q), 2: (r,s), 3: (r,q), 4: (q,s), 5: (s,r)
		if (/0/) {
			$h = Hexagon::Hex->new($x,$y,-$x-$y,%profile);
		} elsif (/1/) {
			$h = Hexagon::Hex->new($y,-$x-$y,$x,%profile);
		} elsif (/2/) {
			$h = Hexagon::Hex->new(-$x-$y,$x,$y,%profile);
		} elsif (/3/) {
			$h = Hexagon::Hex->new($y,$x,-$x-$y,%profile);
		} elsif (/4/) {
			$h = Hexagon::Hex->new($x,-$x-$y,$y,%profile);
		} elsif (/5/) {
			$h = Hexagon::Hex->new(-$x-$y,$y,$x,%profile);
		} else {
			die "Invalid order given to Hexagon::placeHex ($order)\n";
		}
	}
	return $h;
}

package Hexagon::Hex;
use List::Util qw( max );

sub new {
	my ($class,$q,$r,$s,%profile) = @_;
	# assert minimum two coords:
	(defined $q and defined $r) || die "Hexagon::Hex must be created with at least two coordinates!\n";
	(defined $s) || ($s = -$r-$q);
	# assert coords sum as 0:
	($q + $r + $s == 0) || die "Hexagon::Hex was given incorrect coordinates: $q,$r,$s\n";
	my $self = { # we've already made sure each of these values is defined.
		q => $q,
		r => $r,
		s => $s,
		name => ($profile{name} or "$q$r$s"),
		text => ($profile{text} or ""),
	};
	bless $self,$class;
	return $self;
}

sub q {
	return shift->{q};
}

sub r {
	return shift->{r};
}

sub s {
	return shift->{s};
}

sub coords {
	my ($self,$nos) = @_;
	return ($nos ? sprintf("%i,%i",$self->q,$self->r) : sprintf("%i,%i,%i",$self->q,$self->r,$self->s));
}

sub loc { # alias
	return $_[0]->coords(@_);
}

sub equals {
	my ($self,$ego) = @_;
	return ($self->q == $ego->q && $self->r == $ego->r && $self->s == $ego->s);
}

sub add { # takes a coordionate trio or another Hex object
	my ($self,$q,$r,$s) = @_;
	defined $q or $q = 0;
	defined $r or $r = 0;
	defined $s or $s = 0;
	(ref($q) =~ /Fractional/) && return undef; # avoid arithmetic with fractional hexes
	if (ref($q) =~ /Hex/) {
		return Hexagon::Hex->new($self->q + $q->q,$self->r + $q->r, $self->s + $q->s);
	} else {
		($q | $r | $s) || return undef; # return undef if no values given
		return Hexagon::Hex->new($self->q + $q,$self->r + $r, $self->s + $s);
	}
}

sub subtract { # takes a coordionate trio or another Hex object
	my ($self,$q,$r,$s) = @_;
	defined $q or $q = 0;
	defined $r or $r = 0;
	defined $s or $s = 0;
	(ref($q) =~ /Fractional/) && return undef; # avoid arithmetic with fractional hexes
	if (ref($q) =~ /Hex/) {
		return Hexagon::Hex->new($self->q - $q->q,$self->r - $q->r, $self->s - $q->s);
	} else {
		($q | $r | $s) || return undef; # return undef if no values given
		return Hexagon::Hex->new($self->q - $q,$self->r - $r, $self->s - $s);
	}
}

sub multiply { # takes a multiple
	my ($self,$m) = @_;
	defined $m or $m = 0;
	return Hexagon::Hex->new($self->q * $m,$self->r * $m, $self->s * $m);
}

sub hex_length { # converts a difference Hex to a distance in Hexes
	my $self = shift;
	return int((abs($self->q) + abs($self->r) + abs($self->s))/2);
}

sub distance { # inherits subtract's flexibility
	my ($self,$other,$r,$s) = @_;
	return hex_length($self->subtract($other,$r,$s));
}

my %dirs = ( nw => 0, ne => 5, e => 4, se => 3, sw => 2, w => 1 );
my @dirhex =
	(Hexagon::Hex->new(1, 0, -1), Hexagon::Hex->new(1, -1, 0), Hexagon::Hex->new(0, -1, 1),
     Hexagon::Hex->new(-1, 0, 1), Hexagon::Hex->new(-1, 1, 0), Hexagon::Hex->new(0, 1, -1));

sub hex_direction {
	my $dir = shift;
#print "Received direction: $dir...";
	return $dirhex[$dir];
}

sub neighbor {
	my ($self,$dir) = @_;
#print "Received direction $dir ";
	($dir =~ m/[nNsS]?[eEwW]/) && ($dir = $dirs{lc($dir)});
#print "= $dir...";
	my $x = hex_direction($dir);
#printf("%i,%i,%i...",$x->q,$x->r,$x->s);
	return $x;
}

sub hex_lerp { # linear interpolation
	my ($self,$h,$t) = @_;
	return Hexagon::Fractional->new($self->q + ($h->q - $self->q) * $t,
									$self->r + ($h->r - $self->r) * $t,
									$self->s + ($h->s - $self->s) * $t);
}

sub hex_linedraw {
	my ($self,$h) = @_;
	my $n = $self->distance($h);
#print "\n>" . $self->loc . "--" . $h->loc . "< ($n Hexes)\n";
	my @results;
	my $step = 1.0 / ($n ? $n : 1);
	foreach (0 .. $n) {
#		push(@results,$self->neighbor_toward($h));
#		push(@results,Hexagon::Fractional::hex_round(hex_lerp($self,$h,$step * $_)));
		my $h = Hexagon::Fractional::hex_round(hex_lerp($self,$h,$step * $_));
#print "=> " . $h->loc . "\n";
		push(@results,$h);
	}
	return @results;
}

sub neighbor_toward { # returns the neighboring hex in the direction of the given Hex.
	my ($self,$h) = @_;
	my $n = $self->distance($h);
	my $step = 1.0 / ($n ? $n : 1);
	return Hexagon::Fractional::hex_round(hex_lerp($self,$h,$step),2);
}

sub Iama {
	my $self = shift;
	return ref($self);
}

sub rename {
	my ($self,$name) = @_;
	$self->{name} = $name;
}

sub name {
	return $_[0]->{name};
}

package Hexagon::Offset;

package Hexagon::Map;

use Common qw( findIn );
use List::Util qw( min max );
use POSIX qw( floor );

sub new {
	my ($class,$shape,$order,$width,$height) = @_;
	my @shapes = qw( para trii trid hexa hexb rect );
	my $shapenum = findIn($shape,@shapes);
	($shapenum >= 0) || die "Invalid shape '$shape' given. Valid shapes are: " . join(',',@shapes) . ".\n";
	(defined $order) or ($order = 0); # order is 0: (q,r), 1: (s,q), 2: (r,s), 3: (r,q), 4: (q,s), 5: (s,r)
	($shapenum == 5) || ($order = $order % 3); # order can't be more that 2 unless shape is rect.
	my $self = {
		shape => $shapenum,
		width => $width,
		height => ($height or 0),
		order => $order,
		grid => {},
	};
	bless $self,$class;
	return $self;
}

sub map_gen {
	my ($self) = shift;
	for ($self->{shape}) {
		if (/0/) { # para # parallelogram/rhombus
			foreach my $x (1 .. $self->{width}) {
				foreach my $y (1 .. $self->{height}) {
					my $h = Hexagon::placeHex($self->{order},$x - 1,$y - 1,name => "#99f");
					${$self->{grid}}{$h->loc()} = $h;
				}
			}
		} elsif (/1/) { # trii # increasing triangle
			foreach my $x (0 .. $self->{width}) {
				foreach my $y (0 .. $self->{width} - ($x + 1)) {
					my $h = Hexagon::placeHex($self->{order},$x,$y,name => "#99f");
					${$self->{grid}}{$h->loc()} = $h;
				}
			}
		} elsif (/2/) { # trid # decreasing triangle
			foreach my $x (0 .. $self->{width}) {
				foreach my $y ($self->{width} - $x .. $self->{width}) {
					my $h = Hexagon::placeHex($self->{order},$x,$y,name => "#99f");
					${$self->{grid}}{$h->loc()} = $h;
				}
			}
		} elsif (/3/) { # hexa # radius-walk hexes (larger map hex is 90 degrees rotated from shape of component hexes)
			foreach my $x (-$self->{width} .. $self->{width}) {
				my ($a,$z) = (max(-$self->{width},-$x-$self->{width}),min($self->{width},-$x+$self->{width}));
				foreach my $y ($a .. $z) {
					my $h = Hexagon::placeHex($self->{order},$x,$y,name => "#99f");
					${$self->{grid}}{$h->loc()} = $h;
				}
			}
		} elsif (/4/) { # hexb # RPG-style hexes (larger hex matches orientation of smaller hexes, unlike hexa, which makes larger hex orientation 90 degrees from its component hexes)
			my $max = $self->{width}; # our base size.
			$max += ($max % 2); # we need to be even for this method to work.
			($self->{width} == $max) || ($self->{width} = $max); # update if changed
			my ($u,$v,$w) = (int($max /4),$max / 2,3 * int($max /4)); # quartile bounds
			# Markers for aid in finding locations visually:
			my @starters = (0,$w-2,$w+2,0,$w-2,$w+2,$u-1,$max,$max,$u+1,$u+1,$u-1);
			my @ring;
			foreach (0 .. $#starters) {
				($_ % 2) && next; # skip every other index
				my $mark = Hexagon::placeHex($self->{order},$starters[$_],$starters[$_ + 1],name => "#c99", text => sprintf("%d,%d",$starters[$_],$starters[$_ + 1]));
				${$self->{grid}}{$mark->loc()} = $mark;
			}
			# The actual grid builder:
			my ($a,$z) = ($w + 1,$w - 1);
			foreach my $x (0 .. $max) {
				$a -= ($x < $u ? 2 : ($x == $u ? 1 : $x <= $w + 1 ? ($u - $x + 1) % 2 : -1));
				$z -= ($x <= $u ? -1 : ($x == $u + 1 ? 0 : ($x <= $w ? ($x - $u + 1) % 2 : 2)));
				foreach my $y ($a .. $z) {
					my $h = Hexagon::placeHex($self->{order},$x,$y,name => "#99f");
					${$self->{grid}}{$h->loc()} = $h;
				}
			}
			my $center = Hexagon::placeHex($self->{order},$v,$v,name => "#369");
			${$self->{grid}}{center} = $center;
		} elsif (/5/) { # rect
			foreach my $x (0 .. $self->{height} - 1) {
				my $xoff = floor($x/2);
				foreach my $y (-$xoff .. $self->{width} - $xoff - 1) {
					my $h = Hexagon::placeHex($self->{order},$x,$y,name => "#99f");
					${$self->{grid}}{$h->loc()} = $h;
				}
			}
		} else {
			die "Shape $_ not implemented.";
		}
	}
}

sub req_offset {
	my ($self,$scale) = @_;
	my $order = $self->{order};
	my ($xoff,$yoff) = (0,0);
	# get proper offset here
	for ($self->{shape}) {
		if (/0/) { # para # parallelogram/rhombus
			($xoff,$yoff) = (-0.55 * $self->{width} * $scale,-0.33 * $self->{height} * $scale);
		} elsif (/1/) { # trii # increasing triangle
			($xoff,$yoff) = (-0.38 * $self->{width} * $scale,-0.19 * $self->{width} * $scale);
		} elsif (/2/) { # trid # decreasing triangle
			($xoff,$yoff) = (-0.868 * $self->{width} * $scale,-0.39 * $self->{width} * $scale);
		} elsif (/3/) { # hexa # radius-walk hexes (larger map hex is 90 degrees rotated from shape of component hexes)
			# hexa starts from center, so it's always centered.
		} elsif (/4/) { # hexb # RPG-style hexes (larger hex matches orientation of smaller hexes, unlike hexa, which makes larger hex orientation 90 degrees from its component hexes)
			($xoff,$yoff) = (-0.6500744 * $self->{width} * $scale,-(0.375 * $self->{width} * $scale) + ($self->{width} % 4 > 0 && $self->{width} % 4 < 3 ? 23 : 0));
		} elsif (/5/) { # rect
			($xoff,$yoff) = (-0.475 * $self->{width} * $scale,-0.19 * $self->{height} * $scale);
		}
	}

	for ($order) {
		if (/1/) {
			($xoff,$yoff) = (0,-2 * $yoff);
		} elsif (/2/) {
			($xoff,$yoff) = (-$xoff,$yoff);
		}
	}
	return $xoff,$yoff;
}

sub width {
	return $_[0]->{width};
}

sub height {
	return $_[0]->{height};
}

package Hexagon::Orientation;

sub new {
	my ($class,$orient) = @_; # where is the flat edge
	# Set values based on $orient. Orient can be any of: top,left,n,s,e,w,N,S,E,W
	my @values;
	if ($orient eq 'top' || $orient =~ m/[nsNS]/) {
		@values =  (3.0 / 2.0, 0.0, sqrt(3.0) / 2.0, sqrt(3.0),
					2.0 / 3.0, 0.0, -1.0 / 3.0, sqrt(3.0) / 3.0,
					0.0);
	} elsif	($orient eq 'left' || $orient =~ m/[ewEW]/) {
		@values =  (sqrt(3.0), sqrt(3.0) / 2.0, 0.0, 3.0 / 2.0,
					sqrt(3.0) / 3.0, -1.0 / 3.0, 0.0, 2.0 / 3.0,
					0.5);
	} else {
		die "A Hex could not be created using that orientation ($orient).";
	}
	my $self = {
		angle => $values[8], # multiple of 60 degrees
		f0 => $values[0],
		f1 => $values[1],
		f2 => $values[2],
		f3 => $values[3],
		b0 => $values[4],
		b1 => $values[5],
		b2 => $values[6],
		b3 => $values[7],
	};
	bless $self, $class;
	return $self;
}

package Hexagon::Screen;

use Points; # contains Vertex package
use Math::Trig qw( tan pi acos asin );

sub new {
	my ($class,$orientation,$sx,$sy,$ox,$oy) = @_;
	my $sz = Vertex->new(undef,"scrscl",$sx,$sy);
	my $loc = Vertex->new(undef,"scrorig",$ox,$oy);
	my $o = Hexagon::Orientation->new($orientation);
	my $self = {
		orientation => $o,
		size => $sz,
		origin => $loc,
	};
	bless $self,$class;
	return $self;
}

sub ox {
	return $_[0]->{origin}->x;
}
sub oy {
	return $_[0]->{origin}->y;
}
sub sx {
	return $_[0]->{size}->x;
}
sub sy {
	return $_[0]->{size}->y;
}
sub hex_to_pixel {
	my ($self,$h) = @_;
	my $x = ($self->{orientation}->{f0} * $h->q + $self->{orientation}->{f1} * $h->r) * $self->sx;
	my $y = ($self->{orientation}->{f2} * $h->q + $self->{orientation}->{f3} * $h->r) * $self->sy;
	return Vertex->new(undef,undef,$x + $self->ox,$y + $self->oy);
}

sub pixel_to_hex {
	my ($self,$v) = @_;
	my ($x,$y) = (($v->x - $self->ox) / $self->sx,($v->y - $self->oy) / $self->sy);
	my $q = $self->{orientation}->{b0} * $x + $self->{orientation}->{b1} * $y;
	my $r = $self->{orientation}->{b2} * $x + $self->{orientation}->{b3} * $y;
	return Hexagon::Fractional->new($q,$r,-$q-$r);
}

sub corner_offset {
	my ($self,$corner) = @_;
	my $size = $self->{size};
	my $angle = 2.0 * pi * ($corner + $self->{orientation}->{angle}) / 6;
	return Vertex->new(undef,undef,$size->x * cos($angle),$size->y * sin($angle));
}

sub polygon_corners {
	my ($self,$h) = @_;
	my @corners;
	my $c = $self->hex_to_pixel($h);
	foreach (0..5) {
		my $o = $self->corner_offset($_);
		push(@corners,Vertex->new($_,$h->q . "," . $h->r,$c->x + $o->x + $self->ox, $c->y + $o->y + $self->oy));
	}
	return @corners;
}

sub hex_to_lines {
	my ($self,$h,$extra) = @_;
	my @corners = $self->polygon_corners($h);
	my @segments;
	foreach (0 .. $#corners) {
		my $point = $corners[$_];
#print "Corner $_: " . $point->describe() . "\n";
		my ($ox,$oy,$ex,$ey) = ($corners[$_]->loc(),$corners[($_ + 1) % scalar @corners]->loc());
		my $line = Segment->new(0,"poly$_",$ox,$ex,$oy,$ey);
		push(@segments,$line);
	}
	return @segments;
}

sub hex_to_poly {
	my ($self,$h,$extra) = @_;
	my @corners = $self->polygon_corners($h);
	return @corners;
}

package Hexagon::Fractional;

use vars qw(@ISA);
@ISA = qw(Hexagon::Hex);
use Math::Round qw( round );
use POSIX qw( floor );

sub new {
	my ($class,$q,$r,$s,%profile) = @_;
	# assert minimum two coords:
	(defined $q and defined $r) || die "Hexagon::Hex must be created with at least two coordinates!\n";
	(defined $s) || ($s = -$r-$q);
	# assert coords sum as 0:
	($q + $r + $s == 0) || ($s = -$r-$q);
	my $self = { # we've already made sure each of these values is defined.
		q => $q,
		r => $r,
		s => $s,
		name => ($profile{name} or "$q$r$s"),
	};
	bless $self,$class;
	return $self;
}

sub hex_round {
	my ($self,$unused) = @_;
	my $q = int($self->q);
	my $r = int($self->r);
	my $s = int($self->s);
	my $dq = abs($q - $self->q);
	my $dr = abs($r - $self->r);
	my $ds = abs($s - $self->s);
	if ($dq > $dr and $dq > $ds) {
		$q = -$r-$s;
	} elsif($dr > $ds) {
		$r = -$q-$s;
	} else {
		$s = -$q-$r;
	}
	return Hexagon::Hex->new($q,$r,$s);
}

1;
