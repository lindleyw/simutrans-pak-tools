package Pak;

use Mojo::Base -base, -signatures;
use Mojo::Path;
use List::Util;
use File::Find;
use File::Find::Rule;
use File::Basename;
use Path::ExpandTilde;

# An identifying name for the pak
has 'name';

has '_path';          # This must be a path to a pak's root.

sub path ($self, $path = undef) {
    return $self->_path unless defined $path;
    if (ref $path) {
        return $self->_path($path)
    } else {
        return $self->_path(Mojo::Path->new(expand_tilde($path)));
    }
}

sub valid ($self) {
    # Basic check as to whether a valid Pakset exists at the given path
    return 0 unless -e $self->_path;
    
    return 1;
}

################
# LANGUAGE SUPPORT
################

has 'xlat_root' => sub ($self) {
    # Location of the translation text files
    # Assumes the path has been set
    my $xlat = Mojo::Path->new($self->path->to_string);
    push @$xlat, 'text';
    return $xlat->to_string;
};

# Find a list of all the language (translation) files for the pak

has 'languages' => sub ($self) {
    # Return a list of available languages

    my @files_list = File::Find::Rule->file()->name('*.tab')->readable->in($self->xlat_root);
    my @languages = map { (fileparse($_))[0] =~ m/^(.+)\./; $1; } @files_list;

    return [@languages];

};

has 'language_tables' => sub { {}; };

sub load_language($self, $language) {
    # Load a language file
    my $lang_file = Mojo::Path->new($self->xlat_root);
    push @$lang_file, "${language}.tab";
    my $filename = $lang_file->to_string;

    my $translate_from;
    open TRANSLAT, '<', $filename or die "Can't open translation file $filename\n";
    while (<TRANSLAT>) {
	chomp;
	if (/^\s*#(.*)$/) {
	    my $comment_text = $1;
	    if ($comment_text =~ /\blanguage\s*:\s*(\w+)\s(\w+)/i) {
		my ($lang_code, $lang_name) = ($1, $2);
		$self->language_tables->{$lang_code}{name} = $lang_name;
	    }
	} elsif (/\S{1,}/) { # if anything non-blank
	    if (defined $translate_from) {
		$self->language_tables->{$language}{$translate_from} = $_;
		# print "($translate_from) -> ($_)\n";
		undef $translate_from;
	    } else {
		$translate_from = lc($_);
	    }
	}
    }
    close TRANSLAT;
}

has 'language' => sub ($self) {
    # the default language
    
    my $l = $ENV{LANG} =~ m/^(..)/;
    return $1 || 'en';
};

sub translate($self, $string, $language = $self->language) {
    # Translate a string, in the given language or the default if none given
    if (!defined $self->language_tables->{$language}) {
	$self->load_language($language);
    }
    return $self->language_tables->{$language}{lc($string)} || $string || '??';
}

################
# OBJECT SUPPORT
################

# NOTE: "Object" here refers to Simutrans's idea of an object (vehicle, waytype, etc.)
# as defined in the pakset source.

# objects is a simple hash.  Thus,
# $pak->objects()                 # returns the entire pak object-hash 

has objects => sub { {}; };

# $pak->object('objname')         # returns entire parameter-hash for given object
# $pak->object('objname',\{...})  # sets an object's parameter-hash
# $pak->object('objname','objkey') # returns the value of a parameter of an object (objkey must be string)
# $pak->object('objname','objkey','value') # sets parameter value.  value could be a reference.

sub object ($self, $objname = undef, $attr = undef, $value = undef) {
    
    return %{$self->objects} unless defined $objname;
    return $self->objects->{$objname} unless defined $attr;
    return ($self->objects->{$objname} = $attr) if ref($attr);
    return $self->objects->{$objname}{$attr} unless defined $value;
    $self->objects->{$objname}{$attr} = $value;
}

# Returns a hash of objects (in the same format as ->objects() )
# matching the coderef. Uses List::Util::pairgrep to populate
# ($a, $b) each time, $a being the object key, $b being the value hash.
# We then pass these as the two parameters to the callback.
# e.g.,
#   $mypak->grep( sub {$_[1]->{intro_year} > 1960} )
#   $mypak->grep( sub {$_[1]->{obj} eq 'bridge'} )

sub grep ($self, $cb) {
    return {List::Util::pairgrep (sub {&$cb($a, $b)}, %{$self->objects}) };
}

has 'object_types' => sub ($self) { {}; };

# Various Simutrans-object filters before saving to our object

# Instead, make this 'save_object' which filters and then saves in one.

sub save_object ($self, $obj) {

    if (! $obj->{intro_year} && ! $obj->{retire_year}) {
	$obj->{permanent} = 1;
    } else {
        $obj->{intro_year} ||= 1000;
        $obj->{intro_month} ||= 1;
        $obj->{retire_year} ||= 2999;
        $obj->{retire_month} ||= 12;

        # Permit second-level sorting for objects with equal introductory times
        my $power = $obj->{'engine_type'};
        $power = '~~~' if (!length($power)); # sort last

        $obj->{'sort_key'} = sprintf("%4d.%02d %s %4d.%02d",
                                     $obj->{'intro_year'}, $obj->{'intro_month'},
                                     $power,
                                     $obj->{'retire_year'}, $obj->{'retire_month'});
    }

    # Abbreviate loquacious names
    $obj->{'short_name'} = $obj->{'name'};
    if (length($obj->{'short_name'}) > 30) {
	$obj->{'short_name'} =~ s/-([^-]{3})[^-]+/-$1/g;
    }

    if (exists $obj->{'intro_year'}) {
	foreach my $period (qw[intro retire]) {
	    $obj->{$period} = $obj->{$period.'_year'} * 12 + $obj->{$period . '_month'};
	}
    }

    $self->object($obj->{name}, {%$obj}); # save a ref to a copy of the in-passed hash
    $self->object_types->{$obj->{obj}}++;
}

# Parse a line of definition from a .dat file, and add it to our Pak object.
# Builds a hash in a buffer. At eof, pass this 'obj=dummy' to flush the object being built.

use Data::DeepAccess qw(deep_exists deep_get deep_set);
use Mojo::File;

sub _object_definition_line ($self, $line, $fromfile) {
    state %this_object;

    if ($line =~ /^\s*(?<object>\w+)\s*(?:\[(?<subscr>(?:\[|\]|\w|\s)+)\])?\s*=>?\s*(?<value>.*?)\s*\Z/) {
        # /^\s*(?<object>\w+)\s*(?:\[(?<sub1>\w+)\](?:\[(?<sub2>\w+)\])?)?\s*=\s*(?<value>.*?)\s*\Z/) {
	my ($object, $value) = @+{qw(object value)};
        $object = lc($object);
        my @subscripts;
        @subscripts = split /[\[\]]+/, $+{subscr} if defined $+{subscr};
	if (scalar @subscripts || $object =~ /^(?:cursor|icon)\z/) {
	    # NOTE: Values with subscripts, as "value[0]=50", will clobber a previous "value=50".
	    if (ref(\$this_object{$object}) eq 'SCALAR') {
		undef $this_object{$object};
	    }
            my $is_image = 0;
            if ($object =~ /^(front|back)?(image|diagonal|start|ramp|pillar)(up)?2?\z/) {
                # NOTE: certain keys (FrontImage, BackImage) have multiple assumed axes,
                # but not all values will give values for each; thus you may find two
                # entries as:
                #    FrontImage[1][0]    = value1
                #    FrontImage[1][0][1] = value2
                # where value1 is actually for FrontImage[1][0][0][0][0][0], with all the
                # unstated axes defaulting to zero.
                print STDERR "Object " . ($this_object{name} // '??') . " has " . scalar @subscripts . " (6 expected)\n" if scalar @subscripts > 6;
                @subscripts = map { $_ // 0 } @subscripts[0..5]; # Convert to six-dimensional with '0' defaults
                $is_image++;
            } elsif ($object =~ /^((empty|freight)image|cursor|icon)\z/) {
                print STDERR "Object " . ($this_object{name} // '??') . " has " . scalar @subscripts . " (3 expected)\n" if scalar @subscripts > 3;
                @subscripts = map { $_ // 0 } @subscripts[0..2]; # Default to good[0] and livery[0]
                $is_image++;
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
                    $value = { ( map { $_ => $+{$_} } qw(image xoff yoff) ),   # undef OK in these
                               ( map { $_ => $+{$_} // 0 } qw( x y ) ) };      # these default to zero
                    $value->{imagefile} = Mojo::File->new($fromfile)->sibling($value->{image}.'.png') unless $value->{image} eq '-';
                    $this_object{_hasimages}{$object}++;
                }
            }
            # for Data::DeepAccess … Thanks mst and Grinnz on irc.perl.org #perl 2020-06-18
            deep_set(\%this_object, $object, @subscripts, $value);
	} else {
	    if (lc($object) eq 'obj') {
		# Accumulate previous object
		if (defined $this_object{'name'}) {
		    # print "------------------------\n";
                    $this_object{_filename} = $fromfile;
		    $self->save_object(\%this_object);
		    %this_object = ();
		}
	    }
	    $this_object{lc($object)} = $value;
	}
    }
}

################
#
# Pakset-wide image collection
#
################

has 'imagefiles' => sub { {} };

sub _image_level ($self, $object, $level, $hash) {
    if ($level == 0) {
        if (ref $hash ne 'HASH') {
            $DB::single = 1;
            print STDERR "aaagh in $object\n";
            return;
        }
        if (defined $hash->{imagefile}) {
            if (!defined $self->imagefiles->{$hash->{imagefile}}) {
                $self->imagefiles->{$hash->{imagefile}} = {xmax => $hash->{x} // 0, ymax => $hash->{y} // 0};
            } else {
                if (!defined $hash->{x} || !defined $hash->{y}) {
                    print STDERR "no coordinate for image in $object?\n";
                }
                $self->imagefiles->{$hash->{imagefile}}->{xmax} = $hash->{x} if $hash->{x} > $self->imagefiles->{$hash->{imagefile}}->{xmax};
                $self->imagefiles->{$hash->{imagefile}}->{ymax} = $hash->{y} if $hash->{y} > $self->imagefiles->{$hash->{imagefile}}->{ymax};
            }
        }
    } elsif (ref $hash eq 'HASH') {
        foreach my $k (keys %{$hash}) {
            $self->_image_level($object, $level - 1, $hash->{$k}) if defined $hash->{$k};
        }
    }
}

sub find_all_images ($self) {
    
    my $has_images = $self->grep( sub {defined $_[1]->{_hasimages}} );
    foreach my $ii (keys %{$has_images}) {
        my $o = $self->object($ii);
        my @imagekeys = keys %{$o->{_hasimages}};
        foreach my $imagetype (@imagekeys) {
            my @images;
            if ($imagetype =~ /^(?:freight|empty|cursor|icon)/) {
                # {rotation}{good_index} where direction as 'E', 'NE' etc
                $self->_image_level($ii, 3, $o->{$imagetype});
            } else {
                # } elsif ($imagetype =~ /^(front|back)/) {   # Assume all others ahve 6 dimensional axes
                # {rotation}{north-south}{east-west}{height}{animation_frame}{season} where rotation = 0..15
                $self->_image_level($ii, 6, $o->{$imagetype});
            }
        }
    }
}

use Imager;

sub find_image_tile_sizes ($self) {

    # For each found image file,
    # If the file exists, open it with Imager
    # We know that Simutrans image objects always square, and always have a size a multiple of 32
    # Some images may have extra graphical bits (explanatory text) to one side or the bottom,
    # but we assume an image file will be more than one half used, so we can compute the
    # tile size…

    my $images = $self->imagefiles;
    return unless defined $images;
    foreach my $ii (keys %{$images}) {
        my $image_stats = $self->imagefiles->{$ii};
        unless (defined $image_stats->{size}) {
            my $image = Imager->new();
            if ($image->read(file => $ii)) {
                $image_stats->{size} = [$image->getwidth(), $image->getheight()];
                my @guess_tile_size = (
                    ($image->getwidth() / ($self->imagefiles->{$ii}{xmax} + 1)) & ~31,
                    ($image->getheight() / ($self->imagefiles->{$ii}{ymax} + 1)) & ~31 );
                if ($guess_tile_size[0] != $guess_tile_size[1]) {
                    print STDERR '   ' . $guess_tile_size[0].'x'.$guess_tile_size[1].' ?? in '.$ii."\n";
                    # It's almost certainly the smaller of the two.
                    # Guard against picking zero here?
                }
            }
        }
        # Eventually for each object we will do:
        # $self->object($ii, 'tile_size', [$x, $y]);
    }

}

################
#
# OBJECT DATA (.dat) FILES
#
################

has 'dat_files';

sub read_dat ($self, $filename) {

    # Read a .dat file and pass the entire string to be parsed

    open ( my $fh, '<', $filename ) or die "Can't open $filename: $!";
    # print STDERR "** Processing $filename\n";
    while ( my $line = <$fh> ) {
	$self->_object_definition_line($line, $filename);
    }
    close $fh;
    $self->_object_definition_line('obj=dummy', $filename); # flush trailing object. no 'name=x' so can't be saved.
}

sub load ($self, $path = $self->path, $filespec = '*.dat') {
    # Loads (or reloads) the pak's data files
    return undef unless defined $path;
    $self->dat_files( [File::Find::Rule->file()->name($filespec)->readable->in($path)] );

    foreach my $f (@{$self->dat_files}) {
	$self->read_dat($f);
    }
}

################
# IMAGE FILES
################

# Note that the .dat files do not specify the tilesize.  Rather, that
# is done in the makefiles by calling makeobj with the tilesize as a
# parameter.  Furthermore, many paksets have multiple tilesizes, and
# although many give the tilesize in a subdirectory or filename, there
# is no regularity nor requirement to do so.
#
# However, we guess the tilesize by evaluating all the datfiles that
# reference each image file, and then making the assumption that an
# imagefile will be less than twice the maximum x,y tile reference to
# it. Given that tiles are always square (32x32, 128x128) and that we
# look at both x and y dimensions in this calculation (even if a
# particular image has extra width or height, that is almost always in
# one direction, not both, for otherwise 3/4 of the image would be
# unused), this should result in a high success rate.






# Evaluate a filename like "cityhall-1.2.3,-5,-7" to:
#    png => cityhall-1
#    x   => 2   xoffset => -5
#    y   => 3   yoffset => -7




1;
