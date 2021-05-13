package Games::Simutrans::Livery;

# An abstraction of a Simutrans livery.  Various objects (vehicles)
# have liveries in Extended.  It is possible that other objects
# (stations, bridges, etc.) could have liveries in the future.

use Mojo::Base -base, -signatures;
use Mojo::Collection;

################
# 
################

has 'name';        # Short name as used in a Simutrans dat file
has 'description'; # Unused as yet?
has 'intro';       # First observed introduction of this livery in the pakset
has 'retire';      # and last retirement (both as year*12+month)
has 'objects' => sub { Mojo::Collection->new() }; # names of objects in pakset using this livery

sub record_use ($self, $obj) {
    # As a pakset is scanned, we record that this object (the
    # instance, not just the name of it) uses this livery.

    return if $obj->{is_permanent};

    my $name = $obj->name;

    $self->intro($obj->intro) if (!defined $self->intro) || ($self->intro > $obj->intro); # find earliest
    $self->retire($obj->retire) if (!defined $self->retire) || ($self->retire < $obj->retire); # find last

    push @{$self->objects}, $obj->name;
    $self->objects($self->objects->uniq);
}

sub intro_year ($self) { return $self->intro / 12; }
sub intro_month ($self) { return $self->intro % 12 + 1; }
sub retire_year ($self) { return $self->retire / 12; }
sub retire_month ($self) { return $self->retire % 12 + 1; }

1;

__END__

=encoding utf-8

=head1 NAME

Games::Simutrans::Livery - 

=head1 SYNOPSIS

    use Games::Simutrans::Livery;


=head1 DESCRIPTION


=head1 FUNCTIONS


=head1 ATTRIBUTES

=head2 name

Sets or returns the full pathname of the associated .PNG image file.
Ordinarily set at or shortly after creating the object.

=head1 METHODS

=head2 new ( file => '/path/to/file' )

Creates a new C<Image> object.  Ordinarily, and optionally, only the
C<file> attribute will be set.  The file itself is not read until the
C<read> method is invoked.

=head2 record_use ($object)

...

=head1 AUTHOR

William Lindley E<lt>wlindley@wlindley.comE<gt>

=head1 COPYRIGHT

Copyright 2021, William Lindley

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Games::Simutrans::Pak>
