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
	$obj->{synthetic} = 1;	# we could do this,
	return; 		# or we could just not even bother to save
    }

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

    if ($line =~ /^\s*(?<object>\w+)\s*(?:\[(?<subscr>(?:\[|\]|\w|\s)+)\])?\s*=\s*(?<value>.*?)\s*\Z/) {
        # /^\s*(?<object>\w+)\s*(?:\[(?<sub1>\w+)\](?:\[(?<sub2>\w+)\])?)?\s*=\s*(?<value>.*?)\s*\Z/) {
	my ($object, $value) = @+{qw(object value)};
        $object = lc($object);
        my @subscripts;
        @subscripts = split /[\[\]]+/, $+{subscr} if defined $+{subscr};
	if (scalar @subscripts) {
	    # NOTE: Values with subscripts, as "value[0]=50", will clobber a previous "value=50".
	    if (ref(\$this_object{$object}) eq 'SCALAR') {
		undef $this_object{$object};
	    }
            if (defined $subscripts[2]) {
                # NOTE that some keys (FrontImage, BackImage) have assumed number of axes,
                # but not all values will give values for each; thus you may find two
                # entries as:
                #    FrontImage[1][0]    = value1
                #    FrontImage[1][0][1] = value2
                # where value1 is actually for FrontImage[1][0][0][0][0][0], with all the
                # unstated axes defaulting to zero.  We must handle this and not overwrite
                # previous or later values.
                $this_object{$object}{lc(join(',',@subscripts))} = $value;
	    } elsif (defined $subscripts[1]) {
		$this_object{$object}{lc($subscripts[0])}{lc($subscripts[1])} = $value;
	    } else {
		$this_object{$object}{lc($subscripts[0])} = $value;
	    }
	} else {
	    if (lc($object) eq 'obj') {
		# Accumulate previous factory into database
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
# OBJECT DATA (.dat) FILES
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
