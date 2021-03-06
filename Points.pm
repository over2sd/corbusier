use warnings;
use strict;
############################ Vertex (point) Library ############################
package Vertex;

=head2 NAME

Vertex - a package for handling vertices.

=head2 USAGE

    use Points;
    my $vert = Vertex->new(42,"uplt",3,5,0,(interest=>"depot"));

=head2 METHODS

=over

=item new(class,identity,name,x,y,z,meta)

	Returns a new Vertex object.
	Takes these options, all optional:
		class (if not using Vertex->new)
		identity - numeric ID
		name - human-friendly name
		x,y,z - integer coordinates
		meta - a hash of metadata for the particular type of point

=cut

sub new {
	my ($class,$i,$n,$x1,$y1,$z1,%meta) = @_;
#print "Creating a vertex ($i,$n) at ($x1,$y1)...\n";
	my $self = {
        identity => ($i or 0),
        moniker => ($n or 'Unnamed'),
        origin_x => ($x1 or 0),
        origin_y => ($y1 or 0),
        origin_z => ($z1 or 0),
		class => "point",
        immobile => 0,
		metadata => (%meta or {})
	};
	bless $self,$class;
	return $self;
}

=item id(value)

	Returns the Vertex's numeric ID, and sets it, if an argument is provided.

=cut

sub id {
	my ($self,$value) = @_;
	$self->{identity} = $value if defined($value);
	return $self->{identity};
}

=item name(value)

	Returns the Vertex's print-friendly name, and sets it, if an argument is provided.

=cut

sub name {
	my ($self,$value) = @_;
	$self->{moniker} = $value if defined($value);
	return $self->{moniker};
}

=item x(value), y(value), z(value)

	Returns the Vertex's X, Y, or Z coordinate, and sets it, if an argument is provided and the Vertex is not immobilized.

=cut

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

=item loc(showZ)

	Takes an argument determining if the Z coordinate is included.
	Returns the Vertex's location as an array of X, Y, and optionally Z coordinates.

=cut

sub loc {
	my ($self,$use_z) = @_;
	my @loc = ($self->{origin_x},$self->{origin_y});
	if ($use_z) { push(@loc,$self->{origin_z}); }
	return @loc;
}

sub z {
	my ($self,$value) = @_;
	$self->{origin_z} = $value if (defined($value) and not $self->{immobile});
	return $self->{origin_z};
}

=item move({X},{Y},Z)

	Takes arguments for X, Y, and optionally Z coordinates.
	Sets the position of the Vertex.
	Returns 0 if the Vertex is moved, or 1 if a required parameter is missing, or 86 if the point is immobile.

=cut

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

=item wobble({variance})

	Takes a required parameter for the amount of variance.
	Varies the X, Y, and Z values of the Vertex.
	Returns 0 if the Vertex is moved, or 86 if the point is immobile, or -1 if no variance value is given.

=cut

sub wobble {
	use Common qw( vary );
	my ($self,$variance) = @_;
    if ($self->{immobile}) {
        warn "Trying to move immobile vertex $self";
        return 86;
    }
	unless (defined $variance) {
		warn "Variance omittted";
		return -1;
	}
	$self->{origin_x} = Common::vary($self->{origin_x},$variance);
	$self->{origin_y} = Common::vary($self->{origin_y},$variance);
	unless ($self->{origin_z} == 0) { $self->{origin_z} = Common::vary($self->{origin_z},$variance); }
	return 0;
}

=item roundLoc({precision})

	Takes a required parameter for the precision in places.
	Moves the X and Y values of the Vertex to the nearest point of the required precision.
	Returns move result.

=cut

sub roundLoc {
	my ($self,$prec) = @_;
	defined $prec || return;
	use Common qw( nround );
	return $self->move(nround($prec,$self->{origin_x}),nround($prec,$self->{origin_y}));
	if (0) { print "Moved to (" . $self->{origin_x} . "," . $self->{origin_y} . ").\n"; }
}

=item can_move(value)

	Takes an optional parameter to set the Vertex's mobility.
	Makes the Vertex mobile or immobile if the value parameter is set.
	Returns 0 if the Vertex is immobile, or 1 if the point is mobile.

=cut

sub can_move {
	my ($self,$value) = @_;
	if (defined $value) {
        $self->{immobile} = ($value == 0 ? 1 : 0);
    }
    if ($self->{immobile}) { return 0; }
	return 1;
}

=item immobilize()

	Takes no parameters.
	Makes the Vertex immobile.
	Returns 0.

=cut

sub immobilize {
	my $self = shift;
	$self->{immobile} = 1;
	return 0;
}

=item Iama()

	Takes no parameters.
	Returns the object's class (Vertex).

=cut

sub Iama {
	my $self = shift;
	return $self->{class};
}

=item describe(verbose,showZ)

	Takes an optional parameter for verbosity and one for showing th Z coordinat.
	Makes no changes.
	Returns the string describing the object.

=cut

sub describe {
    my ($self,$vv,$showz) = @_;
    unless (defined $vv) { $vv = 0 };
    if ($vv == 0) { return $self->x(),$self->y(),$self->z(); } # 0
	my $class = $self->Iama();
    my $bio = sprintf("I am %s, a%smovable $class at (%.2f,%.2f%s).",$self->name(),( $self->can_move() ? " " : "n im"),$self->x(),$self->y(),($showz ? sprintf(",%.2f",$self->z()) : "" )); # 1
    return $bio;
}

=item clip({minX,minY,maxX,maxY})

	Takes required parameters for minimum X and Y, and maximum X and Y.
	Makes changes to the point to bring it within the minimum and maximum values.
	Returns 0 if the Vertex is moved or within the boundaries, or 1 if a required parameter is missing, or 86 if the point is immobile.

=cut

sub clip {
	my ($self,$minx,$miny,$maxx,$maxy) = @_;
	return 1 unless (defined $minx and defined $maxx and defined $miny and defined $maxy);
	my $x = $self->{origin_x};
	my $y = $self->{origin_y};
	$x = ($x > $maxx ? $maxx : ($x < $minx ? $minx : $x));
	$y = ($y > $maxy ? $maxy : ($y < $miny ? $miny : $y));
	return $self->move($x,$y); # 86 and 0 are handled here.
}

=item getMeta({key})

	Takes required parameter key.
	Makes no changes.
	Returns key value, if present, or undef if not defined.

=cut

sub getMeta {
	my ($self,$key) = @_;
	return $self->{metadata}{$key};
}

=item setMeta({key,value})

	Takes required parameters key and value.
	Makes changes: sets key to value given.
	Returns 0 for successful set, 1 for failure, -1 for missing value or key.

=back

=cut

sub setMeta {
	my ($self,$key,$value) = @_;
	unless (defined $value and defined $key) { return -1; }
#	print "Setting metadata $key to $value.\n";
	($self->{metadata}{$key} = $value) or return 1;
	return 0;
}

############################### Segment Library ################################
package Segment;

use Common qw ( between );

=head2 NAME

Segment - a package for handling lines (line segments).

=head2 USAGE

    use Points;
    my $line = Segment->new(42,"road",3,5,7,9,0,0,(cost=>35,speed=>40));

=head2 METHODS

=over

=item new(ID,NAME,Xo,Xe,Yo,Ye,Zo,Ze,(META HASH))

	Takes the following arguments, all optional:
		ID - numeric identifier
		NAME - friendly name
		Origin X, End X, Origin Y, End Y, Origin Z, End Z - coordinates for the line's position
		META - Metadata in hash form
	Returns a Segment object

=cut

sub new {
	my ($class,$i,$n,$x1,$x2,$y1,$y2,$z1,$z2,%meta) = @_; # needs ID;
	my $self = {
        identity => ($i or 0),
        moniker => ($n or 'Unnamed'),
        origin_x => ($x1 or 0),
        origin_y => ($y1 or 0),
        origin_z => ($z1 or 0),
        distance_x => ($x2-$x1 or 0),
        distance_y => ($y2-$y1 or 0),
        distance_z => ($z2-$z1 or 0),
		metadata => (%meta or {}),
        immobile => 0
	};
	bless $self,$class;
    $self->move_endpoint($x2,$y2,$z2);
	return $self;
}
=item id(VALUE)

	Takes an optional value.
	Sets Segment's numeric ID, if provided with a value.
	Returns the Segment's numeric ID.

=cut

sub id {
	my ($self,$value) = @_;
	$self->{identity} = $value if defined($value);
	return $self->{identity};
}

=item name(VALUE)

	Takes an optional value.
	Sets Segment's friendly name, if provided with a value.
	Returns the Segment's friendly name.

=cut

sub name {
	my ($self,$value) = @_;
	$self->{moniker} = $value if defined($value);
	return $self->{moniker};
}

=item slope()

	Takes no arguments
	Calculates the Segment's slope.
	Returns the Segment's slope.

=cut

sub slope {
    my $self = shift;
    if ($self->{distance_x} == 0) { return undef; } # vertical line, even if length of line is 0, for the sake of simplicity and consistency in the program.
    if ($self->{distance_y} == 0) { return 0; } # horizontal line
    return $self->{distance_y} / $self->{distance_x};
}



=item y_intercept()

	Takes no arguments.
	Calculates the Segment's Y-intercept.
		NB: This function returns the theoretical y-intercept of the segment even if it does not actually cross the y axis.
	Returns the point where the line does or would cross the Y axis.

=cut

sub y_intercept {
    my $self = shift;
    my $m = $self->slope();
    if (not defined $m) { return undef; } # undefined slope == vertical line. No Y-intercept!
	elsif ($m == 0) { return $self->{origin_y}; } # horizontal line. Y is Y.
    my $b = $self->{origin_y} - ($m * $self->{origin_x});
    return $b;
}

=item f({x})

	Takes a required argument X.
	Calculates that X's Y-coordinate on the given line, even if it doesn't exist on this segment (useful for extending the line).
	Returns the corresponding Y value.

=cut

sub f { # f(x)
	my ($self,$x) = @_;
	unless (defined $x) {
		warn "No X value given";
		return undef;
	}
    my $m = $self->slope();
    if (not defined $m) { return undef; } # undefined slope == vertical line. Any y value will do.
	elsif ($m == 0) { return $self->{origin_y}; } # horizontal line. Y is constant.
    my $b = $self->{origin_y} - ($m * $self->{origin_x});
	my $y = $m * $x + $b;
	return $y;
}

=item finv({y})

	Takes a required argument Y.
	Calculates that Y's X-coordinate on the given line, even if it doesn't exist in this segment of the line.
	Returns the corresponding X value.

=cut

sub finv { # f-1(y)
	my ($self,$y) = @_;
	unless (defined $y) {
		warn "No Y value given";
		return undef;
	}
    my $m = $self->slope();
    if (not defined $m) { return $self->{origin_x}; } # undefined slope == vertical line. X is constant.
	elsif ($m == 0) { return undef; } # horizontal line. Any Y will do.
    my $b = $self->{origin_y} - ($m * $self->{origin_x});
	my $x = ($y - $b)/$m;
	return $x;
}

=item ox(value), oy(value), oz(value)

	Take an optional argument for a new origin value.
	Change the origin value for X, Y, or Z, depending on method chosen, if a value is given.
	Return the (new) origin value.

=cut

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

=item xl(length), yl(length), zl(length)

	Take an optional argument for a new length.
	Change the length value for X, Y, or Z, depending on method chosen, if a value is given.
	Return the (new) length along the given axis.

=cut

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

=item ex(), ey(), ez()

	Take no arguments.
	Does nothing.
	Return the endpoint value.

=cut

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

=item azimuth(whole)

	Takes an optional argument to return a whole number as opposed to a precise number.
	Uses getAzimuth to calculate the Segment's azimuth.
	Returns the Segment's azimuth (rotation in degrees from north or the top of the screen).

=cut

sub azimuth {
	my ($self,$whole) = @_;
	return Points::getAzimuth($self->ex(),$self->ey(),$self->ox(),$self->oy(),$whole);
}

=item move({x,y},z)

	Takes required arguments for new X and Y coordinates, and an optional argument for a Z coordinate.
	Moves the line's origin, if not immobilized, to the given location.
	Returns 0 if the line's new location matches the given location, 86 if the line could not be moved, or 1 if one of the required arguments is missing.

=cut

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

=item move_endpoint({x,y},z)

	Takes required arguments for new X and Y coordinates, and an optional argument for a Z coordinate.
	Moves the line's endpoint, if not immobilized, to the given location.
	Returns 0 if the line's new endpoint matches the given location, 86 if the line could not be moved, or 1 if one of the required arguments is missing.

=cut

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

=item double({w,h},nx,ny)

	Takes required arguments for width and height of allowed area, and optional arguments for minimum x and y.
	Makes the Segment twice as long, if that fits in the given boundaries.
	Returns result of move_endpoint.

=cut

sub double {
	my ($self,$w,$h,$minx,$miny) = @_;
	return $self->stretch(2.0,$w,$h,$minx,$miny);
}

=item double({F,w,h},nx,ny)

	Takes required arguments for width and height of allowed area, and optional arguments for minimum x and y.
	Multiplies the Segment length by F, if that fits in the given boundaries, or adjusts it so it does.
	Returns result of move_endpoint.

=cut

sub stretch {
	# TODO: Make an option to Segment->stretch() that will keep the slope intact if the new end is out of bounds
	my ($self,$factor,$w,$h,$minx,$miny) = @_;
	$minx = 0 if not defined $minx;
	$miny = 0 if not defined $miny;
#	print "Min: $minx,$miny\n";
	if (0) { printf("%d,%d =>",$self->ex(),$self->ey()); }
	my $dx = $self->ex() - $self->ox();
	my $dy = $self->ey() - $self->oy();
#	my $x = ($self->ex() + $dx < ($minx or 0) ? ($minx or 0) : ($self->ex() + $dx > $w ? $w : $self->ex() + $dx));
	my $x = ($self->ox() + ($dx * $factor));
#	my $y = ($self->ey() + $dy < ($miny or 0) ? ($miny or 0) : ($self->ey() + $dy > $h ? $h : $self->ey() + $dy));
	my $y = ($self->oy() + ($dy * $factor));
	if (defined $w and $w > $minx and defined $h and $h > $miny) {
		my ($setx,$sety);
		if ($x < $minx) { $setx = $minx; } elsif ($x > $w) { $setx = $w; }
		if (defined $setx) { $x = $setx; $y = $self->f($x); $setx = undef; }
		if ($y < $miny) { $sety = $miny; } elsif ($y > $h) { $sety = $h; }
		if (defined $sety) { $y = $sety; $x = $self->finv($y); }
		if ($x < $minx) { $setx = $minx; } elsif ($x > $w) { $setx = $w; } # recheck in case the adjusted value is outside the boundaries.
		if ($setx) { $x = $setx; } # This will mess up the line's slope, but it'll be within the given field.
	}
	my $rv = $self->move_endpoint($x,$y);
	if (0) { printf("%d,%d\n",$self->ex(),$self->ey()); }
	return $rv;
}

# TODO: Continue documentation

sub move_origin_only {
	my ($self,$x,$y,$z) = @_;
    if ($self->{immobile}) {
        warn "Trying to move immobile line $self";
        return 86;
    }
    if (not defined $x or not defined $y) { return 1; }
	$self->{distance_x} += $self->{origin_x} - $x;
	$self->{distance_y} += $self->{origin_y} - $y;
    $self->{origin_x} = $x;
    $self->{origin_y} = $y;
    if (defined $z) { $self->{distance_z} += $self->{origin_z} - $z; }
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

sub getMeta {
	my ($self,$key) = @_;
	return $self->{metadata}{$key};
}

sub setMeta {
	my ($self,$key,$value) = @_;
	unless (defined $value) { return -1; }
#	print "Setting metadata $key to $value.\n";
	($self->{metadata}{$key} = $value) or return 1;
	return 0;
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

sub roundLoc {
	my ($self,$prec) = @_;
	use Common qw( nround );
	$self->set_ends(nround($prec,$self->{origin_x}),nround($prec,$self->ex()),nround($prec,$self->{origin_y}),nround($prec,$self->ey()),nround($prec,$self->{origin_z}),nround($prec,$self->ez()));
	if (0) { print "Moved to (" . $self->{origin_x} . "," . $self->{origin_y} . "," . $self->{origin_z} . ")-(" . $self->ex() . "," . $self->ey() . "," . $self->ez() . ").\n"; }
}

sub length {
	my $self = shift;
	return Points::getDist($self->ox(),$self->oy(),$self->ex(),$self->ey());
}

sub fparts { # give the necessary function parts
	my $self = shift;
	return ($self->slope(),$self->y_intercept()); # (m,b)
}

sub intersects { #returns a theoretical intersection, even if neither segment contains it.
	my ($self,$line) = @_;
	unless (ref($self) eq 'Segment' and ref($line) eq 'Segment') { return undef; }
	my ($a,$c) = $self->fparts();
	my ($b,$d) = $line->fparts();
#	print "Parts: $a+$c,$b+$d ... ";
	unless (defined $a and defined $b) { # some vertical?
#		print "~";
		my ($x,$y);
		unless (defined $a or defined $b) { # both vertical?
			if (0) { print "[W] Vertical Parallel"; }
			return undef;
		} elsif (defined $a) {
#			print "It's vertical.";
			$x = $line->ox();
			$y = $self->f($x);
		} else {
#			print "I'm vertical.";
			$x = $self->ox();
			$y = $line->f($x);
		}
		return $x,$y;
	} elsif ($a == $b) { # same slope, parallel
#		print "`";
		if (0) { print "[W] Parallel"; }
		unless ($c == $d) { #Not on same path
			return undef;
		}
#	} else {
#		print "^";
	}
	# after Wikipedia:Line-line_intersection#Intersection_of_two_lines_in_the_plane
	my $x = ($d-$c)/($a-$b);
	my $y = $a * $x + $c;
#	print "((($x,$y)))";
	unless (nround(10,$y) == nround(10,$b * $x + $d)) { # 10 digits of precision is sufficient for my^H^Hmost purposes.
		if (1) { printf("\t%.6f =/= %.6f\t",$y,$b * $x + $d); }
		return undef;
	} else {
		return ($x,$y);
	}
}

sub partOfMe {
	my $fuzziness = 0.01; # floating point fuzziness factor
	my ($self,$v) = @_;
	unless (ref($self) eq 'Segment' and ref($v) eq 'Vertex') { return 0; }
	my ($m,$b) = $self->fparts();
	# vertical line handler:
	if (not defined $m and $v->x() - $self->ox() < $fuzziness) { return 1; }
	if (between($v->x(),$self->ox(),$self->ex(),0,$fuzziness)
	and abs($m * $v->x() + $b - $v->y()) < $fuzziness) {
		return 1;
	} else {
		return 0;
	}
}

sub touches { # returns an actual intersection, or undef if the lines don't touch.
	my ($self,$line) = @_;
	unless (ref($self) eq 'Segment' and ref($line) eq 'Segment') { return undef; }
	my $p = Vertex->new(-1,"Junction",$self->intersects($line));
	my $pointself = $self->partOfMe($p);
	my $pointline = $line->partOfMe($p);
	return ($pointself and $pointline,$p->x(),$p->y()); # does it touch?; intersect x; intersect y
	# (intersect is not valid unless does it touch? == 1) Included in all returns in case caller wants to extend a lin to the intersection.
}

sub origin {
	my ($self,$use_z) = @_;
	my @loc = ($self->{origin_x},$self->{origin_y});
	if ($use_z) { push(@loc,$self->{origin_z}); }
	return @loc;
}

sub endpoint {
	my ($self,$use_z) = @_;
	my @loc = ($self->ex(),$self->ey());
	if ($use_z) { push(@loc,$self->ez()); }
	return @loc;
}

sub describe {
    my ($self,$vv,$showz) = @_;
    unless (defined $vv) { $vv = 0 };
    if ($vv == 0) { return $self->ox(),$self->oy(),$self->oz(),$self->ex(),$self->ey(),$self->ez(); } # 0
    my $bio = "I am ". $self->name() . ", a" . ( $self->can_move() ? " " : "n im") . "movable line segment from (" . $self->ox() . "," . $self->oy() . ($showz ? "," . $self->oz() : "" ) . ") to (" .  $self->ex() . "," . $self->ey() . ($showz ? "," . $self->oz() : "" ) . ")."; # 1
    if ($vv > 1) { $bio = "$bio I have a slope of " . $self->slope() . "."; # 2
        if ($vv > 2) { $bio = "$bio If I am long enough in the right direction, I cross 0 at " . $self->y_intercept() . "."; # 3
            if ($vv > 3) {
                $bio = "$bio My length is " . Points::getDist($self->ox(),$self->oy(),$self->ex(),$self->ey()) . "."; # 4
            }
        }
    }
    return $bio;
}

sub orient { # orients the line generally in a particular direction. Useful for preparing a set of lines for duplicate checking.
#currently works in only x,y axes
	my ($self,$dir) = @_;
	$dir = 0 unless (defined $dir); # default to south/east
	if ($dir == 0) { # s/e
		if ($self->oy() > $self->ey()) { # unless ey > oy, line is upside down
			$self->flip();
		} elsif ($self->oy() == $self->ey() and $self->ox() > $self->ex()) { # unless ex > ox, line points west
			$self->flip();
		}
		return;
	} elsif ($dir == 1) { # n/e
		if ($self->oy() < $self->ey()) { # unless ey > oy, line is upside down
			$self->flip();
		} elsif ($self->oy() == $self->ey() and $self->ox() > $self->ex()) { # unless ex > ox, line points west
			$self->flip();
		}
		return;
	} elsif ($dir == 2) { # n/w
		if ($self->oy() < $self->ey()) { # unless ey > oy, line is upside down
			$self->flip();
		} elsif ($self->oy() == $self->ey() and $self->ox() < $self->ex()) { # unless ex > ox, line points west
			$self->flip();
		}
		return;
	} else { # s/w
		if ($self->oy() > $self->ey()) { # unless ey > oy, line is upside down
			$self->flip();
		} elsif ($self->oy() == $self->ey() and $self->ox() < $self->ex()) { # unless ex > ox, line points west
			$self->flip();
		}
		return;
	}
}

sub flip {
	my $self = shift;
	my ($v,$w,$x,$y) = ($self->ex(),$self->ey(),$self->ox(),$self->oy());
	return $self->set_ends($v,$x,$w,$y);
}

################################ Nodes Library #################################
package Node;
use parent -norequire, 'Vertex';

sub new {
	my ($class,$i,$n,$x,$y,$z,$p) = @_;
	my $self = Node->SUPER::new($i,$n,$x,$y,$z);
	my $nodeself = {
		parentID => ($p or -1),
		cost2parent => 0,
		children => [],
		class => "node",
		maximum => 0
	};
	@$self{ keys %$nodeself  } = values %$nodeself;
	bless $self, 'Node';
	return $self;
}

sub describe {
    my ($self,$vv,$showz) = @_;
	if ($vv == 0) { return $self->SUPER::describe($vv,$showz),$self->{maximum},$self->{parentID},$self->{children}; } # just coords (plus my info: max, parent, children)
	my $out = $self->SUPER::describe($vv,$showz);
	$out = "$out My parent is " . $self->{parentID} . ". " . (scalar @{ $self->{children} } ? "My children are " . join(',',@{ $self->{children} }) . ". " : "" ) . "My maximum is " . $self->{maximum} . ".";
	return $out;
}

################################# Mesh Library #################################
package Mesh; # a collection of nodes

sub new {
	my ($class,$i,$n,%meta) = @_;
	my $self = {
		identity => ($i or -1),
		members => [],
		metadata => (%meta or {}),
		moniker => ($n or "Unnamed"),
		lastID => 0
	};
	bless $self, 'Mesh';
	return $self;
}

sub setget {
	my ($self,$op,$val) = @_;
#		identity => ($i or -1),
#		metadata => (%meta or {}),
	if ($op == 0) {
		$self->{identity} = $val if defined($val);
		return $self->{identity};
	} elsif ($op == 1) {
		$self->{moniker} = $val if defined($val);
		return $self->{moniker};
	} else { # assume op is a key for the metadata hash -- give the user credit for using me properly.
		unless (defined $val) { return $self->{metadata}{$op}; } # use op as key
#	print "Setting metadata $key to $value.\n";
		($self->{metadata}{$op} = $val) or return 1;
		return 0;
	}
}

sub addNode {
	my ($self,$n,$x,$y,$z,$p) = @_;
	# sanity check parent ID here?
	my $member = Node->new(++$self->lastid,($n or "Anonymous"),$x,$y,$z,$p);
	push(@{ $self->{members}},$member);
}

sub removeNode {
	# find node in list of members
	# find each child node in list of members
		# set child's parent to grandparent
	# if node is last in line, decrement {lastID}
	# delete node
}

sub connectNodes {
	my ($self,$parentID,$childID) = @_;
	my $par = $self->getMember($parentID);
	my $chi = $self->getMember($childID);
	# If child has a parent, find its old parent in member list
		# remove child from old parent
	# set child's parent to parent
	# add child to parent;s children
}

sub findPath {
}

############################### Points Library #################################
package Points;
use Common qw ( between nround getColorsbyName vary );
use List::Util qw( min );
use Math::Trig qw( tan pi acos asin );
use Math::Round qw( round );
use POSIX qw( floor );

my $debug = 1;
my $termcolors = 0;
my $basecolor = "";
my $funcolor = "";
my @cornerbearings = (0,0,0,0);
my $uid = 1; #time() % 1000; # runtime-unique ID counter for vertices

sub pointIsOnLine { # Don't remember the source of this algorithm, but it was given as a formula.
    if ($debug) { print $funcolor . "pointIsOnLine($basecolor@_$funcolor)$basecolor\n"; }
    my ($x0,$y0,$x1,$y1,$x2,$y2,$fuzziness,$checkrange) = @_; # point, line start, line end, max determinant
	if (defined $checkrange and $checkrange == 1) {
		unless (between($x0,$x1,$x2,0,$fuzziness)) { return 0; }
	}
    my $det = ($x2 - $x1) * ($y0 - $y1) - ($y2 - $y1) * ($x0 - $x1);
	if ($debug) { print "=>$det\n"; }
    return (abs($det) < ($fuzziness or 0));
}

sub findOnLine {
    if ($debug > 2) { print $funcolor . "findOnLine(" . ($debug > 7 ? "$basecolor@_$funcolor" : "") . ")$basecolor\n"; }
    my ($x1,$y1,$x2,$y2,$frac,$whole) = @_;
    my $dx = $x1 - $x2;
    my $dy = $y1 - $y2;
    my $p = Vertex->new($uid++);
	my $x = $x1 - ($dx * $frac);
	my $y = $y1 - ($dy * $frac);
	$p->move($x,$y);
	if ($whole) { $p->roundLoc(0); }
    return $p;
}

sub getDist {
    if ($debug > 1) { print $funcolor . "getDist($basecolor@_$funcolor)$basecolor\n"; }
    my ($x1,$y1,$x2,$y2,$sides) = @_; # point 1, point 2, return all distances?
    my $dx = $x2 - $x1; # preserving sign for rise/run
    my $dy = $y2 - $y1;
	unless ($dx or $dy) { return ($sides ? (0,0,0) : 0); } # same point
#	unless ($dx and $dy) { return ($dx ? $dx : $dy); } # horiz/vert line ## can't do this efficiently with sides variable
    my $d = sqrt($dx**2 + $dy**2); # squaring makes values absolute
	if ($debug > 1) { print "In: $x1,$y1 - $x2,$y2 -- $dy/$dx :: $d\n"; }
    if ($sides) { return $d,$dy,$dx; } # dist, rise, run
    return $d;
}

sub getClosest {
   if ($debug > 1) { print $funcolor . "getClosest($basecolor@_$funcolor)$basecolor\n"; }
    my ($ox,$oy,$ptlr,%exargs) = @_; # origin, reference of list of vertices, hash of extra arguments
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
			if ($debug > 7) { print "Low: " . (defined $lowdist ? $lowdist : "undef") . "(#$lowdex) => $d (#$i) - - - $dy/$dx\n"; }
           $lowdist = $d;
            $lowdex = $i;
        }
    }
    return $lowdex;
}

sub perpDist { # Algorithm source: Wikipedia/Distance_from_a_point_to_a_line
    if ($debug > 1) { print $funcolor . "perpDist($basecolor@_$funcolor)$basecolor\n"; }
    my ($x0,$y0,$x1,$y1,$x2,$y2) = @_; # point, line start, line end
    my $dx = $x2 - $x1;
    my $dy = $y2 - $y1;
	return 0 if ($dx == 0 and $dy == 0);
    my $d = (abs($dy*$x0 - $dx*$y0 - $x1*$y2 + $x2*$y1) / sqrt($dx**2 + $dy**2));
#	print "($d)";
    return $d;
}

sub choosePointAtDist {
    if ($debug > 1) { print $funcolor . "choosePointAtDist($basecolor@_$funcolor)$basecolor\n"; }
    my ($x,$y,$dist,$min,$max,$offset,$whole) = @_; ## center/origin x,y; length of line segment; min,max bearing of line; bearing offset
    my $bearing = rand($max - $min) + $min + $offset;
    return getPointAtDist($x,$y,$dist,$bearing,$whole);
}

sub getPointAtDist {
    if ($debug > 1) { print $funcolor . "getPointAtDist($basecolor@_$funcolor)$basecolor\n"; }
    my ($x,$y,$d,$b,$whole) = @_; ## center/origin x,y; length of line segment; bearing of line segment
	if ($debug > 3) { print "Casting point at $d along $b...\n"; }
	my $p = Vertex->new($uid++);
	$p->setMeta("azimuth",nround(3,$b));
	$b -= 90; # 0 for north, not horizon
	while ($b > 360) { $b-= 360; }
	while ($b < 0) { $b += 360; }
	my $rad = pi / 180;
	my $adj = ($b >= 180 ? 1 : 0);
	if ($adj) {
		$b -= 180;
		$d *= -1;
	}
	$b *= $rad;
    $p->x($x + (cos($b) * $d));
    $p->y($y + (sin($b) * $d));
	if ($whole) { $p->roundLoc(0); }

    return $p;
}

sub chooseAHeading {
    if ($debug) { print $funcolor . "chooseAHeading($basecolor@_$funcolor)$basecolor\n"; }
    my ($offset,$whole) = @_;
    my $bearing = rand(80) + 5 + $offset;
    return $bearing;
}

sub getAHeading {
    if ($debug) { print $funcolor . "getAHeading($basecolor@_$funcolor)$basecolor\n"; }
	# Temporary function for use until I can figure out why the trig-based algorithm isn't giving valid results
	# This function extrapolates bearing based on relationship to known bearing (slope 1 = 45 degrees) and may not be accurate.
	# TODO: Fix this!!!
print "!";
	my ($dx,$dy,$whole,$relative) = @_;
    if (not defined $whole) { $whole = 0; }
    if (not defined $relative) { $relative = 0; }
#	print "Given $dy/$dx:";
	if ($dx == 0) { return ($dy > 0 ? 180 : 0); } # vertical line has 0 or 180 degree heading. identical point has heading of 0.
	if ($dy == 0) { return ($dx > 0 ? 90 : ($relative ? -90 : 270)); } # horizontal line is 90 or 270/-90 degree heading
	my $h = $dy / $dx * 45; # slope of 1 = 45 degree heading
#	print " $h=>";
	if ($dx < 0) {
		$h = ($relative ? $h - 90 : ($dy < 0 ? 360 - $h : 180 - $h));
#		print " $h->";
	} else {
		$h = 90 + $h;
#		print " $h+>";
	}
	if ($whole) { $h = floor($h + 0.5); }
#	print " $h\n";
	return $h;
}

#This function is not producing correct results. :(
sub oldGetAHeading {
    if ($debug) { print $funcolor . "getAHeading($basecolor@_$funcolor)$basecolor\n"; }
    my ($dx,$dy,$offset,$whole,$relative) = @_;
    if (not defined $whole) { $whole = 0; }
    if (not defined $relative) { $relative = 1; }
    my $h = atan($dx,$dy)*180/pi;
    $h = $h + ($offset or 0);
    if ($whole) {
        $h = round($h)
    }
	if (not $relative) {
		return $h + 180; # absolute heading (0-360)
    } elsif ($h < -180) {
        $h += 360;
    } elsif ($h > 180) {
        $h -= 360;
    }
    return $h;
}

# after wiki/Law_of_cosines
sub getAzimuth { # north azimuth (point $cx,0) is 0 degrees.
    if ($debug > 1) { print $funcolor . "getAzimuth($basecolor@_$funcolor)$basecolor\n"; }
	my ($cx,$cy,$tx,$ty,$whole,$relative) = @_; # center x/y, target x/y
	if (not defined $whole) { $whole = 0; }
	my ($hyp,$rise,$run) = getDist($cx,$cy,$tx,$ty,1);
	if ($hyp == 0) { print "\n[W] Identical point!\n"; return 0; }
	if ($rise == 0) {
		if ($debug > 8) { print "Nocalc horiz\n"; } return ($run > 0 ? 90 : 270);
	} elsif ($run == 0) {
		if ($debug > 8) { print "Nocalc vert\n"; } return ($rise > 0 ? 180 : 0);
	}
	my $opp = abs($rise > $run ? $run : $rise);
#	my $adj = abs($rise > $run ? $rise : $run);
	my $angle = asin($opp/$hyp)/pi*180;
	if ($cx > $tx) { # Getting an accurate azimuth reading has to be the kludgiest, most convoluted thing I have ever had to code.
		if ($cy > $ty) { $angle = 270 + ($rise > $run ? 90 - $angle : $angle);
		} else { $angle = 270 - (90 - $angle); }
	} else {
		if ($cy > $ty) { $angle = 90 - $angle;
		} else { $angle = (abs($rise) > abs($run) ? 180 - $angle : 90 + $angle); }
	}
	if ($debug > 1) { printf("Angle: %.2f Opp: %.2f Hyp: %.2f\n",$angle,$opp,$hyp); }
	if ($whole) { $angle = floor($angle + 0.5); }
	if ($relative and $angle > 180) { $angle -= 360; }
	return $angle;
}

sub closestCardinal {
	my ($x,$y,$w,$h) = @_; # point, w/h of field
	if (not defined $h or not defined $w or not defined $y or not defined $x) { warn "closestCardinal takes 4 arguments: x,y,width,height"; return -1; }
	my @trials = (Vertex->new(0,'',int($w/2),0),Vertex->new(0,'',int($w * 0.8),0),Vertex->new(0,'',$w,int($h/5)),Vertex->new(0,'',$w,int($h/2)),Vertex->new(0,'',int($w),int($h * 0.8)),Vertex->new(0,'',int($w * 0.8),$h),Vertex->new(0,'',int($w/2),$h),Vertex->new(0,'',int($w/5),$h),Vertex->new(0,'',0,$h),Vertex->new(0,'',0,int($h * 0.8)),Vertex->new(0,'',0,int($h/2)),Vertex->new(0,'',0,int($h/5)),Vertex->new(0,'',0,0));
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
	return $cd; # returns a cardinal direction, clockwise from 0 (N or top) to 11 (NNW or topleft-top)
}

sub costlyRectify {
    my ($ar,$v) = @_;
    my @existing = @$ar;
    my @xs;
    my @ys;
    foreach my $i (0 .. $#existing) {
        push(@xs,$existing[$i]->x());
		push(@ys,$existing[$i]->y());
    }
	my $basex = min(@xs) - 20;
	my $topx = max(@xs) + 20;
	my $basey = min(@ys) - 20;
	my $topy = max(@ys) + 20;
	my @xpoints = ($basex .. $topx);
	my @ypoints = ($basey .. $topy);
    foreach my $i (0 .. $#existing) {
		splice(@xpoints,$existing[$i]->x() - 5,10);
		splice(@ypoints,$existing[$i]->y() - 5,10);
    }
	use Data::Dumper;
	print Dumper @xpoints;
	$v->move(0,0);
	print "This function isn't finished! Finish it!\n";
	exit(-99);
	return $v;
}

sub placePoint {
    if ($debug > 5) { print $funcolor . "placePoint($basecolor@_$funcolor)$basecolor\n"; }
	my ($v,$xrange,$xbase,$yrange,$ybase,$listref,$mindist,$maxtries) = @_;
	my $d = 0;
	my $j = 0;
    do {
        my $x = floor(rand(abs($xrange))) + $xbase;
        my $y = floor(rand(abs($yrange))) + $ybase;
		#print "\nTrying ($x,$y)...";
        $v->move($x,$y);
        $d = $mindist + 1;
        foreach my $ii (@$listref) {
            $d = min($d,Points::getDist($ii->x(),$ii->y(),$v->x(),$v->y()));
        }
		#print "Nearest at least $d units away...";
        if ($j > 5) { $v->move(costlyRectify($listref,$v)); $x = $v->x(); $y = $v->y(); print "Moving old points"; }
		$j++;
    } until ($d > $mindist or $j > $maxtries); # minimum distance between squares
	#print ".end dist: $d (" . ( $d > $mindist ? "true" : "false") . ")\n";
	return ($d > $mindist);
}

my $cornershavebeenset = 0;
sub setCornerHeadings {
	my ($w,$h) = @_;
	my @c = ($w / 2,$h / 2); # center point
	$cornerbearings[0] = getAzimuth($c[0],$c[1] ,0,0,0);
#	print "\nN: " . getAzimuth($c[0],$c[1] ,$c[0],0,1);
	$cornerbearings[1] = getAzimuth($c[0],$c[1] ,$w,0,0);
#	print "\nE: " . getAzimuth($c[0],$c[1] ,$w,$c[1],1);
	$cornerbearings[2] = getAzimuth($c[0],$c[1] ,$w,$h,0);
#	print "\nS: " . getAzimuth($c[0],$c[1] ,$c[0],$h,1);
	$cornerbearings[3] = getAzimuth($c[0],$c[1] ,0,$h,0);
#	print "\nW: " . getAzimuth($c[0],$c[1] ,0,$c[1],1);
	$cornershavebeenset = 1;
	printf("Your corner bearings are set to: %.2f,%.2f,%.2f,%.2f.\n",$cornerbearings[0],$cornerbearings[1],$cornerbearings[2],$cornerbearings[3]);
	return 0;
}

=item slopeFromAzimuth()
	Given an azimuth (absolute bearing from 0=N), returns a list containing the slope of the line (or undef for vertical) and which edge the azimuth intersects N=0; W=3.
	Use of this function to find an edge assumes that setCornerHeadings has previously been called with the size of your current field. If the corner headings have not been set, it will return "unknown" for the edge value.
=cut

# TODO: Make a Field package that stores field size and can be given as a metadatum to Segment and Vertex objects.
sub slopeFromAzimuth {
	my $az = shift;
	$az = 0 if ($az == 360);
	if ($az == 0 or $az == 180) { # vertical line
		return (undef,($az ? 2 : 0));
	}
	my $slope = ($az > 180 ? $az - 180 : $az);
	if ($slope >= 45 and $slope <= 135) {	# accurate between m=1 and m=-1
#		print ":!:";
		$slope = -$slope / 45 + 2;
	}	else {
#		This function seems kludgey and wrong, but it gives results more accurate to my expectations than the trig functions I've found elsewhere.
		my $sloperise = ($slope < 45 ? 45 : -45);
		my $sloperun = ($slope < 45 ? $slope : 180 - $slope);
		$slope = $sloperise / $sloperun;
#		print "$slope = $sloperise / $sloperun\n";
	}
	my $edge = ($az < $cornerbearings[0] ? ($az < $cornerbearings[3] ? ($az < $cornerbearings[2] ? ($az < $cornerbearings[1] ? 0 : 1) : 2) : 3) : 0);
	unless ($cornershavebeenset) { $edge = "unknown"; }

	return ($slope,$edge);
}

=item interceptFromAz()
	Given a bearing, the width and height of the field, and optionally an origin in the form of an ordered pair, returns a vertex at that bearing's intersection with the edge of the field.
=cut
sub interceptFromAz {
	my ($b,$w,$h,$ox,$oy) = @_;
	my $isvertical = 0;
	unless (defined $b and defined $w and defined $h) { return undef; }
	unless (defined $ox and defined $oy) { $ox = $w/2; $oy = $h/2; }
	unless ($cornershavebeenset) { setCornerHeadings($w,$h); }
	my ($slope,$edge) = Points::slopeFromAzimuth($b);
	unless (defined $slope) { $slope = "vert"; $isvertical = 1; }
	if ($edge eq "unknown") { return undef; }
	# I guess this function is good enough, for now.
	my $point = Vertex->new(-1,($isvertical ? "$b=>$edge" : sprintf("%d=>%d",$b,$edge)));
	if ($isvertical) {
		$point->move($ox,($edge == 0 ? 0 : $h));
		return $point;
	}
	if ($slope == 0.00 and $edge ne 1 and $edge ne 3) { print "Slope error!\n"; exit(-6); }
	# we no longer need the bearing, so we're replacing it with the Y-intercept of the line.
	$b = $oy - ($slope * $ox);
	my ($x,$y) = (0,0);
	for ($edge) {
		if (/0/) { $y = 0; $x = $w - int(0.5 + (($y - $b) / $slope));
		} elsif (/1/) { $x = $w; $y = $h - int(0.5 + ($slope * $x) + $b);
		} elsif (/2/) { $y = $h; $x = $w - int(0.5 + (($y - $b) / $slope));
		} elsif (/3/) { $x = 0; $y = $h - int(0.5 + ($slope * $x) + $b);
		} else {
			print "ERROR\n"; return undef;
		}
	}
	# Maybe these lines will help and not gather every exit into the corners...
	if ($y > $h) { $x = ($x > $y - $w ? $x - $w + $y : $x); $y = $h; }
	if ($x > $w) { $y = ($y < $x - $h ? $y - $h + $x : $y); $x = $h; }
	if ($y < 0) { $x = ($x < $w + $y ? $x - $y : $x); $y = 0; }
	if ($x < 0) { $y = ($y < $h + $x ? $y - $x : $y); $x = 0; }
	$point->move($x,$y);
	return $point;
}

sub useRUID {
	return $uid++;
}

sub getAzimuths {
	my ($x,$y,$arref,$end) = @_;
	unless (ref($arref) eq "ARRAY") { return undef; }
	unless (defined $end) { $end = "o"; }
	my @list = @$arref;
	my @azlist;
	my $lisv = (ref($list[0]) eq "Vertex");
	foreach my $p (@list) {
		my $v = ($lisv ? $p->x() : ("$end" ne "e" ? $p->ox() : $p->ex()));
		my $w = ($lisv ? $p->y() : ("$end" ne "e" ? $p->oy() : $p->ey()));
		my $a = getAzimuth($x,$y,$v,$w);
		push(@azlist,$a);
	}
	return @azlist;
}

sub twist {
	my ($origlin,$div) = @_;
	unless ($div) { print "[E] Can't divide by 0!\n"; return undef; }
	unless ($div > 1) { print "[W] Can't divide line into 0-1 segments."; return (); }
	$div--;
	my @letters = ("a".."z","A".."Z",0..9); # Not sure what happens if you split your line into more than 62 pieces, but that is unlikely...
	my (@bears,@points,@lines);
	my ($current,$maxaz,$minaz) = (0.00,$origlin->azimuth() + 55,$origlin->azimuth() - 55);
	my $i = $origlin->azimuth();
	my $tp = Vertex->new();
	my @o = ($origlin->ox(),$origlin->oy());
	my @t = ($origlin->ex(),$origlin->ey());
	my $lp = Vertex->new(0,"last",@t);
	my $ep = Vertex->new(0,"first",@o);
	for (0 .. int($div/2) - 1) {
		$i = vary($i,5 + $_);
		if ($i < $minaz) {
			print "+";
			my $var = $minaz - $i;
			$i = $minaz + $var;
		} elsif ($i > $maxaz) {
			print "-";
			my $var = $i - $maxaz;
			$i = $maxaz - $var;
		}
		push(@bears,$i);
	}
	foreach (0 .. $#bears) {
		my $dist = $origlin->length() * (($_ + 1)/($div + 2));
		$tp = getPointAtDist($lp->loc(),$dist,$bears[$_],1);
		push(@points,$tp);
	}
	my $dist = (1/$div) * $origlin->length();
	foreach (int($div/2) .. $div - 1) {
		$lp->move($tp->loc());
		$i = getAzimuth(@t,$lp->loc(),1);
		if ($i > $maxaz) { print "+"; $i = $maxaz - (5 + ($div - $_)); }
		elsif ($i < $minaz) { print "-"; $i = $minaz + (5 + ($div - $_)); }
		$i = vary($i,5 + ($div - $_));
		$tp = getPointAtDist($lp->loc(),$dist,$i,1);
		push(@points,$tp);
	}
	foreach (reverse @points) {
		my $line = Segment->new($origlin->id(),sprintf("%s-%s",$origlin->name(),shift @letters));
		$line->set_ends($_->x(),$ep->x(),$_->y(),$ep->y());
		push(@lines,$line);
		$ep = $_;
	}
	$origlin->move_origin_only($ep->x(),$ep->y());
	$origlin->name(sprintf("%s-%s",$origlin->name(),shift @letters));
	return @lines;
}

sub seg_remove_dup {
	my ($list,$orient,$precision) = @_;
	my %xvals;
	defined($precision) or $precision = 0;
	my @uniquelines;
	foreach (@$list) {
		defined($orient) && $_->orient($orient); # orient all lines the same way (pointing south or east) to make comparing them simpler.
		my $key = sprintf("%s",nround($precision,$_->ox()));
		unless (exists $xvals{$key}) {
			$xvals{$key} = [];
		}
		push (@{$xvals{$key}},$_);
	}
	foreach my $k (keys %xvals) {
#		print "Checking $k...";
		my @lines = unique_segments($xvals{$k});
		push(@uniquelines,@lines);
	}
	return @uniquelines;
}

sub unique_segments {
	my $lines = shift;
	my @uniques;
	foreach my $a (@$lines) {
		my $u = 1;
		foreach my $b (@uniques) {
			(int($a->oy()) == int($b->oy()) && int($a->ey()) == int($b->ey()) &&
			 int($a->ox()) == int($b->ox()) && int($a->ex()) == int($b->ex()))
			 and $u = 0;
		}
		my $c = (($u and push(@uniques,$a)) ? '' : '-');
		print $c if (0);
	}
	return @uniques;
}

sub enableTermcolors {
	$termcolors = 1;
	$basecolor = Common::getColorsbyName("base");
	$funcolor = Common::getColorsbyName("ltgreen");
}

=back

=cut
1;
