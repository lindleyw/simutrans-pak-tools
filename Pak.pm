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
# e.g., $mypak->grep( sub {$_[1]->{intro_year} > 1960} )

sub grep ($self, $cb) {
    return {List::Util::pairgrep (sub {&$cb($a, $b)}, %{$self->objects}) };
}

has 'object_types' => sub ($self) { {}; };

# This must be a path to a pak's root.

has 'path';

has 'dat_files' => sub ($self) {
    return [File::Find::Rule->file()->name('*.dat')->readable->in(expand_tilde($self->path))];
};

has 'xlat_root' => sub ($self) {
    # Assumes the path has been set
    my $xlat = Mojo::Path->new(expand_filename($self->path));
    push @$xlat, 'text';
    return $xlat->to_string;
};


# Find a list of all the language (translation) files for the pak

has 'languages' => sub ($self) {

    my @files_list = File::Find::Rule->file()->name('*.tab')->readable->in(expand_filename($self->xlat_root));
    my @languages = map { (fileparse($_))[0] =~ m/^(.+)\./; $1; } @files_list;

    return [@languages];

};

has 'language_tables' => sub { {}; };

# Load a language file

sub load_language($self, $language) {
    my $lang_file = Mojo::Path->new(expand_filename($self->xlat_root));
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

# the default language

has 'language' => sub ($self) {
    my $l = $ENV{LANG} =~ m/^(..)/;
    return $1 || 'en';
};

# Translate a string, in the given language or the default if none given

sub translate($self, $string, $language = $self->language) {
    if (!defined $self->language_tables->{$language}) {
	$self->load_language($language);
    }
    return $self->language_tables->{$language}{lc($string)} || $string || '??';
}

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

sub _object_definition_line ($self, $line) {
    state %this_object;

    if ($line =~ /^\s*(?<object>\w+)\s*(?:\[(?<sub1>\w+)\](?:\[(?<sub2>\w+)\])?)?\s*=\s*(?<value>.*?)\s*\Z/) {
	my ($object, $value, $sub1, $sub2) = @+{qw(object value sub1 sub2)};
	if (defined $sub1) {
	    # my $subb = defined $sub1 ? "[$sub1]" . (defined $sub2 ? "[$sub2]" : '') : '';
	    # print "  [$object]$subb = [$value]\n";

	    # If we have both: "value=50" and "value[0]=50", the later will clobber the former.
	    if (ref(\$this_object{lc($object)}) eq 'SCALAR') {
		undef $this_object{lc($object)};
	    }
	    if (defined $sub2) {
		$this_object{lc($object)}{lc($sub1)}{lc($sub2)} = $value;
	    } else {
		$this_object{lc($object)}{lc($sub1)} = $value;
	    }
	} else {
	    if (lc($object) eq 'obj') {
		# Accumulate previous factory into database
		if (defined $this_object{'name'}) {
		    # print "------------------------\n";
		    $self->save_object(\%this_object);
		    %this_object = ();
		}
	    }
	    $this_object{lc($object)} = $value;
	    # print "  [$1] = [$3]\n";
	}
    }
}

# Read a .dat file and pass the entire string to be parsed

sub read_dat ($self, $filename) {
    open( my $fh, '<', expand_filename($filename) ) or die "Can't open $filename: $!";
    # print STDERR "** Processing $filename\n";
    while ( my $line = <$fh> ) {
	$self->_object_definition_line($line);
    }
    close $fh;
    $self->_object_definition_line('obj=dummy'); # flush trailing object. no 'name=x' so can't be saved.
}

sub read_data_files ($self) {
    foreach my $f (@{$self->dat_files}) {
	$self->read_dat($f);
    }
}

1;
