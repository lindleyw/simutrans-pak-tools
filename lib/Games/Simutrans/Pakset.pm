package Games::Simutrans::Pakset;

use Mojo::Base -base, -signatures;
use Mojo::Path;
use Mojo::File;
use List::Util;
use Path::ExpandTilde;

has 'name';           # An identifying name for the pak

has '_path';          # This must be a path to a pakset's root.

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

has '_xlat_root';

sub xlat_root ($self, $new_root = undef) {
    # Location of the translation text files.  Lazy assignment in case
    # we access before the path has been set.
    my $xlat;
    if (defined $new_root) {
        $xlat = ref $new_root ? $new_root : Mojo::Path->new($new_root);
    } else {
        if (!defined $self->_xlat_root) {
            return undef unless defined $self->path;
            $xlat = Mojo::Path->new($self->path->to_string);
            push @$xlat, 'text';
            $self->_xlat_root($xlat);
        }
    }
    return $self->_xlat_root->to_string;
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

use Games::Simutrans::Pak;

################
#
#  TODO: save_object, _object_definition_line() to be moved into Pak.pm
#
################

sub save ($self, $obj) {

    # Remember each Pak object instance
    if (defined $obj) {
        $self->object($obj->{name}, $obj);
        $self->object_types->{$obj->{obj}}++;
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
# Liveries
#
################

use Games::Simutrans::Livery;

has 'liveries' => sub { {}; };

sub scan_liveries ($self, $type = undef) {

    my $objects;
    if (defined $type) {
        $objects = $self->objects_of_type($type);
    } else {
        $objects = $self->objects;
    }

    foreach my $obj_name (keys %{$objects}) {

        my $this_object = $objects->{$obj_name};
        my $liveries = $this_object->{liverytype};

        next unless (defined $liveries) && (ref $liveries eq 'HASH');
        foreach my $l (values %{$liveries}) {
            $self->liveries->{$l} //= Games::Simutrans::Livery->new(name => $l);
            my $livery = $self->liveries->{$l};
            $livery->record_use($this_object);
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
        next if $objects->{$obj_name}{is_permanent};
        my $this_type = $objects->{$obj_name}{obj};
        foreach my $period (0..1) {
            # Value will be the opposite end of the availability period
            $timeline->{$objects->{$obj_name}{$periods[$period]}}{$periods[$period]}{$this_type}{$objects->{$obj_name}{name}} =
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
    my $dat_text;
    eval { $dat_text = Mojo::File->new($filename)->slurp; 1; } or die "Can't open $filename: $!";

    # A dat file may contain multiple objects, separated by a dashed line.
    foreach my $object_text (split(/\n-{2,}\s*\n/, $dat_text)) {
        my $new_object = Games::Simutrans::Pak->new->from_string({ file => $filename,
                                                                   text => $object_text});
        $self->save($new_object) if defined $new_object;
    }

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

    $self->load_language();
    $self->find_all_images();
    $self->find_image_tile_sizes();
    $self->scan_liveries();
}

1;
