package Games::Simutrans::Pak;

#
# Represents an individual Simutrans object (although multiple objects
# may reside in an actual *.pak file).
#

use Mojo::Base -base, -signatures;

# For the moment, this package itself does very little.

has 'intro';
has 'retire';
has 'name';

sub save ($self, $obj) {

    return undef if ($obj->{obj} // '') =~ /^dummy/;
    if (! $obj->{intro_year} && ! $obj->{retire_year}) {
	$obj->{is_permanent} = 1;
        $obj->{sort_key} = '0000';
    } else {
        $obj->{intro_year} ||= 1000;
        $obj->{intro_month} ||= 1;
        $obj->{retire_year} ||= 2999;
        $obj->{retire_month} ||= 12;
        foreach my $period (qw(intro retire)) {
            $obj->{$period} = $obj->{$period . '_year'} . '-' . $obj->{$period . '_month'};
        }
        $obj->{is_internal} = $obj->{intro_year} < 100; # Internal object

        # Permit second-level sorting for objects with equal introductory times
        my $power = $obj->{'engine_type'};
        $power = '~~~' if (!length($power)); # sort last

        $obj->{'sort_key'} = sprintf("%4d.%02d %s %4d.%02d",
                                     $obj->{'intro_year'}, $obj->{'intro_month'},
                                     $power,
                                     $obj->{'retire_year'}, $obj->{'retire_month'});
    }

    # Abbreviate loquacious names
    $obj->{'short_name'} = $obj->{'name'} // '(none)';
    if (length($obj->{'short_name'}) > 30) {
	$obj->{'short_name'} =~ s/-([^-]{3})[^-]+/-$1/g;
    }

    if (exists $obj->{'intro_year'}) {
	foreach my $period (qw[intro retire]) {
	    $obj->{$period} = $obj->{$period.'_year'} * 12 + $obj->{$period . '_month'};
	}
    }

    # For now, simply copy each value
    foreach my $k (keys %{$obj}) {
        $self->{$k} = $obj->{$k};
    }
    return $self;        # for chaining
}

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

1;
