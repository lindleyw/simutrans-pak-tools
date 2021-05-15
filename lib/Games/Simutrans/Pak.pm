package Games::Simutrans::Pak;

#
# Represents an individual Simutrans object (although multiple objects
# may reside in an actual *.pak file).
#

use Mojo::Base -base, -signatures;
use Data::DeepAccess qw(deep_exists deep_get deep_set);

# For the moment, this package itself does very little.

has '_intro';
has '_retire';
has 'name';

################
#
# Create an object from, e.g., a dat file section.
#
################

sub from_string ($self, $params) {

    my $filename = $params->{file};
    my $dat_text = $params->{text};

    my %this_object;
    $this_object{_filename} = $filename;

    foreach my $line (split("\n", $dat_text)) {
        $line =~ s/\#.*\Z//; # Remove comments

        if ($line =~ /^\s*(?<object>\w+)\s*(?:\[(?<subscr>(?:\[|\]|\w|\s)+)\])?\s*=(?<nozoom>>?)\s*(?<value>.*?)\s*\Z/) {
            # /^\s*(?<object>\w+)\s*(?:\[(?<sub1>\w+)\](?:\[(?<sub2>\w+)\])?)?\s*=\s*(?<value>.*?)\s*\Z/) {
            my ($object, $value, $nozoom) = @+{qw(object value)};
            $object = lc($object);
            $this_object{_nozoom}{$object} = 1 if $+{nozoom};  # icon=>foo  means foo.png without change as map is zoomed
            my @subscripts;
            @subscripts = split /[\[\]]+/, $+{subscr} if defined $+{subscr};
            if (scalar @subscripts || $object =~ /^(?:cursor|icon)\z/) {
                # NOTE: Values with subscripts, as "value[0]=50", will clobber a previous "value=50".
                if (ref(\$this_object{$object}) eq 'SCALAR') {
                    undef $this_object{$object};
                }
                my $is_image = 0;
                my $dimensions;
                if ($object =~ /^(front|back)?(image|diagonal|start|ramp|pillar)(up)?2?\z/) {
                    # NOTE: certain keys (FrontImage, BackImage) have multiple assumed axes,
                    # but not all values will give values for each; thus you may find two
                    # entries as:
                    #    FrontImage[1][0]    = value1
                    #    FrontImage[1][0][1] = value2
                    # where value1 is actually for FrontImage[1][0][0][0][0][0], with all the
                    # unstated axes defaulting to zero.
                    $dimensions = (defined $1 && $2 eq 'image') ? 6 : 2;  # frontimage, backimage are 6-dim;
                    # all other images are two-dimensional (one axis plus season).
                    $is_image++;
                } elsif ($object =~ /^((empty|freight)image|cursor|icon)\z/) {
                    $dimensions = 3;
                    $is_image++;
                }
                if (defined $dimensions) {
                    if (scalar @subscripts > $dimensions) {
                        print STDERR "Object " . ($this_object{name} // '??') . " has " .
                        scalar @subscripts . " ($dimensions expected)\n";
                    }
                    # Convert to correction number of dimensions, with '0' defaults:
                    @subscripts = map { $_ // 0 } @subscripts[0..($dimensions-1)]; 
                }
                if ($is_image) {
                    # Can begin as './something' but otherwise file cannot have dots within
                    if ($value =~ /^(?<image>\.?[^.]+)           
                                   (?:\.(?<y>\d+)
                                       (?:\.(?<x>\d+))?
                                       (?:,(?<xoff>\d+)
                                           (?:,(?<yoff>\d+))?
                                       )?
                                   )?/xa) {
                        $value = { ( map { defined $+{$_} ? ($_ => $+{$_}) : () } qw(image xoff yoff) ),   # skip each if undef
                                   ( map { $_ => $+{$_} // 0 } qw( x y ) ) };      # these default to zero
                        # Override above in case of older "imagefile.3" form, which assumes column (x) only
                        if (!defined $+{x} && $object =~ /^(front|back|empty|freight)/) {  # 
                            $value->{x} = $+{y} // 0; $value->{y} = 0;
                        }
                        $value->{imagefile} = Mojo::File->new($filename)->sibling($value->{image}.'.png') unless $value->{image} eq '-';
                        $this_object{_hasimages}{$object}++;
                    }
                }
                # for Data::DeepAccess … Thanks mst and Grinnz on irc.perl.org #perl 2020-06-18
                deep_set(\%this_object, $object, (map { lc } (@subscripts)), $value);
            } else {
                $this_object{lc($object)} = $value;
            }
        }
    }

    ################
    # Finalization
    ################

    if (! $this_object{intro_year} && ! $this_object{retire_year}) {
	$this_object{_is_permanent} = 1;
        $this_object{_sort_key} = '0000';
    } else {
        $this_object{intro_year} ||= 1000;
        $this_object{intro_month} ||= 1;
        $this_object{retire_year} ||= 2999;
        $this_object{retire_month} ||= 12;
        $this_object{_is_internal} = $this_object{intro_year} < 100; # Internal object

        # Permit second-level sorting for objects with equal introductory times
        my $power = $this_object{'engine_type'};
        $power = '~~~' if (!length($power)); # sort last

        $this_object{_sort_key} = sprintf("%4d.%02d %s %4d.%02d",
                                          $this_object{'intro_year'}, $this_object{'intro_month'},
                                          $power,
                                          $this_object{'retire_year'}, $this_object{'retire_month'});
    }

    # Abbreviate loquacious names
    $this_object{_short_name} = $this_object{'name'} // '(none)';
    if (length($this_object{_short_name}) > 30) {
	$this_object{_short_name} =~ s/-([^-]{3})[^-]+/-$1/g;
    }

    # en-passant spelling correction
    $this_object{max_length} //= delete $this_object{max_lenght} if defined $this_object{max_lenght};

    if (exists $this_object{intro_year}) {
	foreach my $event (qw[intro retire]) {
            foreach my $period (qw[month year]) {
                my $setit = $event . '_' . $period;
                $self->$setit (delete $this_object{$setit});
            }
	}
    }

    ################
    # Copy values into returned (self) object
    ################

    foreach my $k (keys %this_object) {
        $self->{$k} = $this_object{$k};
    }

    return defined $this_object{obj} ? $self : undef;
}

################

sub intro ($self) { return $self->_intro; }
sub retire ($self) { return $self->_retire; }

sub intro_year ($self, $value = undef) {
    $self->_intro( $value * 12 + (($self->intro() // 0) % 12) ) if defined $value;
    return defined $self->intro() ? int($self->intro() / 12) : undef;
}

sub intro_month ($self, $value = undef) {
    $self->_intro( (($self->intro_year() // 0) * 12) + $value  - 1) if defined $value;
    return defined $self->intro() ? ($self->intro() % 12) + 1 : undef;
}

sub retire_year ($self, $value = undef) {
    $self->_retire( $value * 12 + (($self->retire() // 0) % 12) ) if defined $value;
    return defined $self->retire() ? int($self->retire() / 12) : undef;
}

sub retire_month ($self, $value = undef) {
    $self->_retire( (($self->retire_year() // 0) * 12) + $value - 1) if defined $value;
    return defined $self->retire() ? ($self->retire() % 12) + 1 : undef;
}

################
#
# TODO: Change this into from_string() with appropriate changes in
# Pakset.pm
#
################

sub save ($self, $obj) {

    return undef if ($obj->{obj} // '') =~ /^dummy/;
    return $self;        # for chaining
}

################

sub waytype_text ($self) {
    # Return a standardized, shorter version of the waytype
    my $waytype = $self->{'waytype'};
    if (defined $waytype) {
        $waytype =~ s/_track//;
        $waytype =~ s/track/train/;
        $waytype =~ s/water/ship/;
        $waytype =~ s/narrowgauge/narrow/;
    }
    return $waytype // '';
}

sub payload_text ($self) {
    # Return a standardized, shorter version of the capacities (from the payload)
    my $capacity;
    if ( defined $self->{payload} ) {
        if ( ref $self->{payload} eq 'HASH' ) {
            $capacity = join(',', $self->{payload}->@{ sort keys %{$self->{payload}} } );
        } else {
            $capacity = sprintf("%3du", $self->{payload});
        }
    }
    return $capacity // '--';
}

sub _recursively_do_something {
    my ($self, @stuff) = @_;
    return '';
}

sub deep_print ($self, $attribute, @keys) {
    my $value = deep_get($self->{$attribute}, @keys);
    if (ref $value eq 'HASH') {
        my $text;
        my $has_values = [];
        my $is_image = exists $value->{image} && exists $value->{x};
        foreach my $k (sort keys %{$value}) {
            if ($is_image && !ref deep_get($self->{$attribute}, @keys, $k)) {
                push @{$has_values}, $k;
            } else {
                $text .= $self->deep_print($attribute, @keys, $k);
            }
        }
        if (scalar @{$has_values}) {
            # TODO: Only if this is an image!
            my $image_spec = $value->{image} .
            '.' . ($value->{y}//0) .
            '.' . ($value->{x}//0);
            $image_spec .= ',' . ($value->{xoff}//0) . ',' . ($value->{yoff}//0)
            if defined $value->{xoff} || $value->{yoff};
            return $attribute . '[' . join('][', @keys) . ']=' . $image_spec . "\n";
        }
        return $text;
    } else {
        return $attribute . '[' . join('][', @keys) . ']=' . $value . "\n";
    }
}

sub to_string ($self) {
    # Preferred order to emit attributes.  Any others will be emitted
    # in random order after these.
    my $emit_order = Mojo::Collection->new(qw( obj type name copyright 
                                               intro_year intro_month retire_year retire_month 
                                               waytype own_waytype engine_type chance DistributionWeight
                                               needs_ground seasons climates
                                               noinfo noconstruction
                                               build_time level offset_left
                                               enables_pax enables_post enables_ware
                                               catg metric weight_per_unit value speed_bonus
                                               freight payload speed topspeed cost maintenance runningcost
                                               power gear height weight length sound smoke
                                               loading_time
                                               max_length max_height pillar_distance pillar_asymmetric system_type
                                               MapColor
                                               dims
                                               icon cursor
                                               FrontImage BackImage BackImage2
                                               FreightImageType FreightImage EmptyImage
                                               openimage front_openimage closedimage front_closedimage
                                         ));
    my %to_emit = map { ($_, $self->{$_}) } grep { $_ !~ /^_/ } keys %{$self};

    # Replace synthetic dates with external representations
    if (defined $self->intro()) {
        @to_emit{qw(intro_year intro_month retire_year retire_month)} =
        ($self->intro_year(), $self->intro_month(), $self->retire_year(), $self->retire_month());
    };

    # Emit common attributes in a desirable order
    my $text = '';
    $emit_order->each(sub { my $emit_key = lc($_); # %to_emit has keys from object, not as capitalized above
                            if (defined $to_emit{$emit_key}) {
                              if (ref $self->{$emit_key} ne 'HASH') {
                                  $text .= "$_=" . $to_emit{$emit_key} . "\n";  # simple value
                              } else {
                                  $text .= $self->deep_print($emit_key);
                              }
                              delete $to_emit{$emit_key};
                          }
                      });
    $text .= "\n";

    # Emit remaining attributes
    foreach my $k (sort keys %to_emit) {
        if (defined $self->{$k}) {
            if (ref $self->{$k} ne 'HASH') {
                $text .= "$k=" . $self->{$k} . "\n";  # simple value
            } else {
                $text .= $self->deep_print($k);
            }
        }
    }
    return $text . "------\n\n";
}



1;
