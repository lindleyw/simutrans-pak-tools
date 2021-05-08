package Games::Simutrans::Pak;

use Mojo::Base -base, -signatures;
use Mojo::Path;
use Mojo::File;
use List::Util;
use Path::ExpandTilde;
use Data::DeepAccess qw(deep_exists deep_get deep_set);

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

# use File::Find;
# use File::Find::Rule;
# use File::Basename;

has 'languages' => sub ($self) {
    # Return a list of available languages

    my $files_collection = Mojo::File->new($self->xlat_root)->list_tree->grep(sub{$_ =~ /\.tab\z/});
    my @languages = $files_collection->map(sub { $_->basename('.tab') } );
    # my @files_list = File::Find::Rule->file()->name('*.tab')->readable->in($self->xlat_root);
    # my @languages = map { (fileparse($_))[0] =~ m/^(.+)\./; $1; } @files_list;

    return [@languages];

};

has 'language' => sub ($self, $lang = undef) {
    # the default language
    
    my $l = $lang // $ENV{LANGUAGE} // $ENV{LANG}; $l =~ m/^(..)/;
    return $1 || 'en';
};

has 'language_tables' => sub { {}; };

sub load_language($self, $language = $self->language) {
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

# objects is a simple hash.  Thus, $pak->objects() returns the entire
# pak object-hash

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

sub objects_of_type ($self, $type) {
    return $self->grep( sub {$_[1]->{obj} eq $type} )
}

# Various Simutrans-object filters before saving to our object

# Instead, make this 'save_object' which filters and then saves in one.

sub save_object ($self, $obj) {

    return if $obj->{obj} =~ /^dummy/;
    if (! $obj->{intro_year} && ! $obj->{retire_year}) {
	$obj->{is_permanent} = 1;
        $obj->{sort_key} = '0000';
    } else {
        $obj->{intro_year} ||= 1000;
        $obj->{intro_month} ||= 1;
        $obj->{retire_year} ||= 2999;
        $obj->{retire_month} ||= 12;
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

sub _object_definition_line ($self, $line, $fromfile) {
    state %this_object;

    $line =~ s/\#.*\Z//; # Remove comments
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
                    # Override above in case of older "imagefile.3" form, which assumes column (x) only
                    if (!defined $+{x} && $object =~ /^(front|back|empty|freight)/) {  # 
                        $value->{x} = $+{y} // 0; $value->{y} = 0;
                    }
                    $value->{imagefile} = Mojo::File->new($fromfile)->sibling($value->{image}.'.png') unless $value->{image} eq '-';
                    $this_object{_hasimages}{$object}++;
                }
            }
            # for Data::DeepAccess … Thanks mst and Grinnz on irc.perl.org #perl 2020-06-18
            deep_set(\%this_object, $object, (map { lc } (@subscripts)), $value);
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

use Games::Simutrans::Image;
has 'imagefiles' => sub { {} };

sub _image_level ($self, $object_name, $level, $image_spec) {
    # Drills down recursively, regardless of starting level, so complete proper structure exists
    if ($level == 0) {
        if (ref $image_spec ne 'HASH') {
            print STDERR "Improperly formed $object_name\n";
            return;
        }
        my $image_file_path = scalar $image_spec->{imagefile};
        if (defined $image_file_path) {
            if (!defined $self->imagefiles->{ $image_file_path }) {
                $self->imagefiles->{ $image_file_path } = Games::Simutrans::Image->new(
                    file => $image_file_path ,  # Full path, as string
                );
            }
            $self->imagefiles->{$image_file_path}->record_grid_coordinate($image_spec->{x}, $image_spec->{y});
        }
    } elsif (ref $image_spec eq 'HASH') {
        foreach my $k (keys %{$image_spec}) {
            $self->_image_level($object_name, $level - 1, $image_spec->{$k}) if defined $image_spec->{$k};
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
                # } elsif ($imagetype =~ /^(front|back)/) {   # Assume all others have 6 dimensional axes
                # {rotation}{north-south}{east-west}{height}{animation_frame}{season} where rotation = 0..15
                $self->_image_level($ii, 6, $o->{$imagetype});
            }
        }
    }
}

################
# IMAGE FILES
################

# See comments in Games::Simutrans::Image for details on why and how
# we impute the tilesize for each image.

sub find_image_tile_sizes ($self, $params = {}) {

    my $images = $self->imagefiles;
    return unless defined $images;
    foreach my $file (keys %{$images}) {
        if (defined $self->imagefiles->{$file}) {
            $self->imagefiles->{$file}->read($params);  # Computes tile size, and saves when parameter save=1.
        }
    }
}

################
#
# Timeline
#
################

sub timeline ($self, $type = undef) {
    
    my $objects;
    if (defined $type) {
        $objects = $self->objects_of_type($type);
    } else {
        $objects = $self->objects;
    }

    my $timeline;

    my @periods = (qw(intro retire));
    foreach my $obj_name (keys %{$objects}) {
        next if $objects->{$obj_name}{permanent};
        my $type = $objects->{$obj_name}{obj};
        foreach my $period (0..1) {
            # Value will be the opposite end of the availability period
            $timeline->{$objects->{$obj_name}{$periods[$period]}}{$periods[$period]}{$type}{$objects->{$obj_name}{name}} =
            $objects->{$obj_name}{$periods[1-$period]};
        }
    }

    return $timeline;
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

sub load ($self, $path = $self->path) {
    # Loads (or reloads) the pak's data files
    return undef unless defined $path;

    my $file_path = Mojo::File->new($path);
    # Load directory recursively; or load a single file.
    $self->dat_files( -d $file_path ? $file_path->list_tree->grep(sub{/\.dat\z/i}) : Mojo::Collection->new($file_path) );

    $self->dat_files->each ( sub {
	$self->read_dat($_);
    });

    $self->find_all_images();
    $self->find_image_tile_sizes();
    $self->load_language();
}

1;
