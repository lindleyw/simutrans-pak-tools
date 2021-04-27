package Games::Simutrans::Image;

# An abstraction of a Simutrans PNG image file, as might be attached to a .dat file.
# Note, this is at a lower level than the .dat attchment information -- this is just the
# image alone.

use Mojo::Base -base, -signatures;

################
# COLORS
################

sub _player_colors ($type = 'std') {
    state $player_colors = {std => ['#244b67', '#395e7c', '#4c7191', '#6084a7', '#7497bd', '#88abd3', '#9cbee9', '#b0d2ff'],
                            alt => ['#7b5803', '#8e6f04', '#a18605', '#b49d07', '#c6b408', '#d9cb0a', '#ece20b', '#fff90d']};
    return $player_colors->{$type};
}

sub _player_color ($type = 'std', $index = 0) {
    return _player_colors($type)->[$index];
}

sub player_color ($type, $index) {
    return Imager::Color->new(web => _player_color($type, $index));
}

################

my @_mapcolor_rgb = (   # from simgraph16.cc
	36, 75, 103,
	57, 94, 124,
	76, 113, 145,
	96, 132, 167,
	116, 151, 189,
	136, 171, 211,
	156, 190, 233,
	176, 210, 255,
	88, 88, 88,
	107, 107, 107,
	125, 125, 125,
	144, 144, 144,
	162, 162, 162,
	181, 181, 181,
	200, 200, 200,
	219, 219, 219,
	17, 55, 133,
	27, 71, 150,
	37, 86, 167,
	48, 102, 185,
	58, 117, 202,
	69, 133, 220,
	79, 149, 237,
	90, 165, 255,
	123, 88, 3,
	142, 111, 4,
	161, 134, 5,
	180, 157, 7,
	198, 180, 8,
	217, 203, 10,
	236, 226, 11,
	255, 249, 13,
	86, 32, 14,
	110, 40, 16,
	134, 48, 18,
	158, 57, 20,
	182, 65, 22,
	206, 74, 24,
	230, 82, 26,
	255, 91, 28,
	34, 59, 10,
	44, 80, 14,
	53, 101, 18,
	63, 122, 22,
	77, 143, 29,
	92, 164, 37,
	106, 185, 44,
	121, 207, 52,
	0, 86, 78,
	0, 108, 98,
	0, 130, 118,
	0, 152, 138,
	0, 174, 158,
	0, 196, 178,
	0, 218, 198,
	0, 241, 219,
	74, 7, 122,
	95, 21, 139,
	116, 37, 156,
	138, 53, 173,
	160, 69, 191,
	181, 85, 208,
	203, 101, 225,
	225, 117, 243,
	59, 41, 0,
	83, 55, 0,
	107, 69, 0,
	131, 84, 0,
	155, 98, 0,
	179, 113, 0,
	203, 128, 0,
	227, 143, 0,
	87, 0, 43,
	111, 11, 69,
	135, 28, 92,
	159, 45, 115,
	183, 62, 138,
	230, 74, 174,
	245, 121, 194,
	255, 156, 209,
	20, 48, 10,
	44, 74, 28,
	68, 99, 45,
	93, 124, 62,
	118, 149, 79,
	143, 174, 96,
	168, 199, 113,
	193, 225, 130,
	54, 19, 29,
	82, 44, 44,
	110, 69, 58,
	139, 95, 72,
	168, 121, 86,
	197, 147, 101,
	226, 173, 115,
	255, 199, 130,
	8, 11, 100,
	14, 22, 116,
	20, 33, 139,
	26, 44, 162,
	41, 74, 185,
	57, 104, 208,
	76, 132, 231,
	96, 160, 255,
	43, 30, 46,
	68, 50, 85,
	93, 70, 110,
	118, 91, 130,
	143, 111, 170,
	168, 132, 190,
	193, 153, 210,
	219, 174, 230,
	63, 18, 12,
	90, 38, 30,
	117, 58, 42,
	145, 78, 55,
	172, 98, 67,
	200, 118, 80,
	227, 138, 92,
	255, 159, 105,
	11, 68, 30,
	33, 94, 56,
	54, 120, 81,
	76, 147, 106,
	98, 174, 131,
	120, 201, 156,
	142, 228, 181,
	164, 255, 207,
	64, 0, 0,
	96, 0, 0,
	128, 0, 0,
	192, 0, 0,
	255, 0, 0,
	255, 64, 64,
	255, 96, 96,
	255, 128, 128,
	0, 128, 0,
	0, 196, 0,
	0, 225, 0,
	0, 240, 0,
	0, 255, 0,
	64, 255, 64,
	94, 255, 94,
	128, 255, 128,
	0, 0, 128,
	0, 0, 192,
	0, 0, 224,
	0, 0, 255,
	0, 64, 255,
	0, 94, 255,
	0, 106, 255,
	0, 128, 255,
	128, 64, 0,
	193, 97, 0,
	215, 107, 0,
	255, 128, 0,
	255, 128, 0,
	255, 149, 43,
	255, 170, 85,
	255, 193, 132,
	8, 52, 0,
	16, 64, 0,
	32, 80, 4,
	48, 96, 4,
	64, 112, 12,
	84, 132, 20,
	104, 148, 28,
	128, 168, 44,
	164, 164, 0,
	193, 193, 0,
	215, 215, 0,
	255, 255, 0,
	255, 255, 32,
	255, 255, 64,
	255, 255, 128,
	255, 255, 172,
	32, 4, 0,
	64, 20, 8,
	84, 28, 16,
	108, 44, 28,
	128, 56, 40,
	148, 72, 56,
	168, 92, 76,
	184, 108, 88,
	64, 0, 0,
	96, 8, 0,
	112, 16, 0,
	120, 32, 8,
	138, 64, 16,
	156, 72, 32,
	174, 96, 48,
	192, 128, 64,
	32, 32, 0,
	64, 64, 0,
	96, 96, 0,
	128, 128, 0,
	144, 144, 0,
	172, 172, 0,
	192, 192, 0,
	224, 224, 0,
	64, 96, 8,
	80, 108, 32,
	96, 120, 48,
	112, 144, 56,
	128, 172, 64,
	150, 210, 68,
	172, 238, 80,
	192, 255, 96,
	32, 32, 32,
	48, 48, 48,
	64, 64, 64,
	80, 80, 80,
	96, 96, 96,
	172, 172, 172,
	236, 236, 236,
	255, 255, 255,
	41, 41, 54,
	60, 45, 70,
	75, 62, 108,
	95, 77, 136,
	113, 105, 150,
	135, 120, 176,
	165, 145, 218,
	198, 191, 232,
    );

my @_mapcolor;

while (scalar @_mapcolor_rgb) {
    push @_mapcolor, Imager::Color->new(shift @_mapcolor_rgb, shift @_mapcolor_rgb, shift @_mapcolor_rgb);
}

sub mapcolor ($index) {
    return $_mapcolor[$index];
}

################
# COLOR PIXEL MANIPULATION
# 
# These 'replace_' functions return Imager objects, as opposed to
# modifying the object's image.
#
# They all use Imager::transform2 (see Imager::Engines manpage) and
# are inspired by a little program by Tony Cook (tonyc),
# http://www.perlmonks.org/?node_id=497355
################

sub replace_rgb ($self, $constants) {
    # Replace one (r,g,b) with another

    my $rpnexpr = <<'EOS';
x y getp1 !pix
@pix red !pred @pred from_red eq
@pix green !pgreen @pgreen from_green eq and
@pix blue !pblue @pblue from_blue eq and !match
@match rr @pred if
@match gg @pgreen if
@match bb @pblue if
@pix alpha
rgba
EOS

    $constants->@{qw(from_red from_green from_blue from_alpha)}=$constants->{from_color}->rgba;
    $constants->@{qw(rr gg bb aa)}=$constants->{to_color}->rgba;

    return Imager::transform2({ rpnexpr => $rpnexpr,
                                constants => $constants,
                                channels => 4},
                              $self->image);
}

sub replace_hue ($self, $constants) {

    my $rpnexpr = <<'EOS';
x y getp1 !pix
@pix hue !phue @phue from_hue from_hue_thresh + lt @phue from_hue from_hue_thresh - gt and new_hue @phue if
@pix sat
@pix value
@pix alpha
hsva
EOS

    return Imager::transform2({ rpnexpr => $rpnexpr,
                                constants => $constants,
                                channels => 4},
                              $self->image);
}

sub replace_hue_sat ($self, $constants) {

    my $rpnexpr = <<'EOS';
x y getp1 !pix
@pix hue !phue @phue from_hue from_hue_thresh + lt @phue from_hue from_hue_thresh - gt and !match
@match new_hue @phue if
@match new_sat @pix sat if
@pix value
@pix alpha
hsva
EOS

    return Imager::transform2({ rpnexpr => $rpnexpr,
                                constants => $constants,
                                channels => 4},
                              $self->image);
}

sub replace_color_range ($self, $constants) {

    my $rpnexpr = <<'EOS';
x y getp1 !pix
@pix hue !phue
@pix value !pval

@phue from_hue from_hue_thresh + le @phue from_hue from_hue_thresh - ge and
@pval from_value from_value_thresh + le @pval from_value from_value_thresh - ge and
@pix sat 0.15 gt @pix value 0.15 gt and
and and
rr gg bb rgb @pix if

EOS

    $constants->@{qw(rr gg bb aa)} = $constants->{to_color}->rgba;

    return Imager::transform2({ rpnexpr => $rpnexpr,
                                constants => $constants,
                                channels => 4},
                              $self->image);
}

################
# Change an object's image to/from a single player/alternate color.
# These modify the object's image (unlike the above 'replace_' subs)
################

sub change_to_player_color ($self, $colortype, $value, $opts) {
    # $colortype should be 'std' or 'alt' for standard / alternate player color
    # $value should be 0..7 for the level

    $self->image( $self->replace_color_range( {%{$opts},
                                               to_color => player_color($colortype, $value)
                                           }));
}

sub change_from_player_color ($self, $colortype, $value, $opts) {
    # $colortype should be 'std' or 'alt' for standard / alternate player color
    # $value should be 0..7 for the level

    $self->image( $self->replace_rgb( {%{$opts},
                                       from_color => player_color($colortype, $value),
                                   }));
}

################
# Change a color range to/from player/alternate colors
################

sub change_to_player_colors ($self, $opts = {}) {

    my ($colortype,
        $hue, $hue_threshold,
        $levels, $offset, $level_offset) =
        ( $opts->{type} // $opts->{colortype} ,
          $opts->{hue},
          $opts->{hue_threshold} // $opts->{hue_thresh} // $opts->{hue_t},
          $opts->{levels} // 8,  # Normally, use all eight player/alternate colors
          $opts->{offset} // 0,  # NOTE: offset+level must be ≤ 8 
          $opts->{level_offset} // $opts->{level_o} // 0.1, # By default, do not modify values very near black
          # NOTE: Could also introduce a gamma parameter
      );

    my $v_threshold = (1-$level_offset)/($levels*2);            # for levels=2, this is 1/4
    foreach my $value ( $offset .. ($offset + $levels) - 1 ) {    # skipping 0 so black does not get modified!
        # Replace gradations of values of the given hue, with special player colors
        my $v = ($value * (1 - $level_offset) / $levels) + $level_offset + $v_threshold;  # for levels=2, this will be 1/4 and then 3/4.
        $self->change_to_player_color($colortype, $value, {
            from_hue => $hue,
            from_hue_thresh => $hue_threshold,
            from_value => $v,
            from_value_thresh => $v_threshold,
        });
    }

}

sub change_from_player_colors ($self, $opts = {}) {
    # Replace a set of eight player colors to gradations of the given hue.
    # Replacement could be a hue or a mapcolor.
    my ($colortype,
        $hue, $saturation, $offset, $levels,
        $mapcolor) =
        ( $opts->{type} // $opts->{colortype} ,
          $opts->{hue},
          $opts->{sat} // $opts->{saturation},
          $opts->{offset} // 0,
          $opts->{levels} // 8,
          $opts->{map} // $opts->{mapcolor},
      );
    my @to_colors;
    if (defined $mapcolor) {
        # change to a mapcolor scale
        my $start_mapcolor = $mapcolor & 0xf8; # mask off bottom 3 bits
        for my $i ( $offset .. ($offset + $levels) - 1) {
            push @to_colors, $_mapcolor[$start_mapcolor + $i];
        }
    } else {
        # TODO: calculate an array of output colors based on fixed hue
        # and varying lightness/saturation ...(how to improve this
        # basic algorithm?)
        $saturation //= 1;   # Saturation given as 0..1
        for my $i ( $offset .. ($offset + $levels) - 1 ) {
            push @to_colors, Imager::Color->new( hue => $hue, s => $saturation , v => ($i+1) /  8 );
        }
    }
    for my $i ( 0 .. scalar @to_colors - 1) {
        $self->change_from_player_color( $colortype, $offset + $i, { to_color => $to_colors[$i] } );
    }

}

################
# IMAGE FILE HANDLING
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

use Imager;

has 'file';        # Filename
has 'image';       # Imager object
has 'modified';    # File modification time (perl's -M)
has 'width';       # from image
has 'height';
has 'xmax';        # Retained while reading the collection of .dat files
has 'ymax';
has 'tilesize';    # Imputed square grid size (calculated from aggregate of .dat files); computed at read() if xmax, ymax are known.
has 'is_transparent'; # set when we convert heritage transparent-equivalent color to actual transparency

sub record_grid_coordinate ($self, $x, $y) {
    # As each dat file is scanned, we make a record of each grid coordinate that was used.

    $self->xmax($x) if $x > ($self->xmax // -1);
    $self->ymax($y) if $y > ($self->ymax // -1);

}

sub read ($self, $params = {}) {
    my $file = defined $params->{file} ? $params->{file} : $self->file();
    return undef unless defined $file;

    if ( (!defined $self->modified) || ( -M $file != $self->modified ) || ($params->{save}) ) {
        # Haven't read yet, or was modified
        
        my $image = $self->image // Imager->new();
        # NOTE: Older Simutrans PNG are afflicted with 'pHYs out of place' errors,
        # which may be safely ignored, thus the flag below.
        $image->read(file => $file, png_ignore_benign_errors => 1);

        # For each found image file,
        # If the file exists, open it with Imager
        # We know that Simutrans image objects are always square, and always have a size a multiple of 32
        # Some images may have extra graphical bits (explanatory text) to one side or the bottom,
        # but we assume an image file will be more than one half used, so we can compute the
        # tile size…

        if (defined $image && $image->getwidth()) {
            $self->file($file);
            $self->modified(-M $file);
            $self->width ($image->getwidth() );
            $self->height($image->getheight());
            # Check for heritage pseudo-transparency by examining farthest lower-left pixel, which
            # due to Simutrans's standard masking should be either transparent, or the heritage pseudo-transparent color.
            $self->is_transparent( ($image->getpixel( x => 0, y => $image->getheight() - 1)->rgba)[3] == 0);

            if (defined $self->xmax && defined $self->ymax) {
                my @guess_tile_size = (
                    ($self->width() / ($self->xmax + 1)) & ~31,
                    ($self->height() / ($self->ymax + 1)) & ~31 );
                # It's almost certainly the smaller of the two.
                my $tile_size = $guess_tile_size[0];
                $tile_size = $guess_tile_size[1] if $tile_size > $guess_tile_size[1]; # Choose smaller
                $self->tilesize ( $tile_size );
            }
        }

        $self->image($image) if $params->{save};
    }
}

sub write ($self, $filename) {
    $self->image->write( file => $filename );
}

sub flush ($self) {
    # Free the memory associated with the image
    $self->modified(undef);
    undef $self->{image};
    $self;
}

sub make_transparent ($self) {
    return if $self->is_transparent;
    $self->read({save => 1}) unless defined $self->image;
    if (defined $self->image) {
        my $temp_img = Imager->new(xsize=>$self->width, ysize=>$self->height, channels=>4);
        return unless defined $temp_img;
        $temp_img->box(filled=>1, color=>Imager::Color->new(231,255,255));
        my $new_img = $temp_img->difference(other=>$self->image);
        return unless $new_img;
        undef $self->{image};
        $self->image($new_img);
        $self->is_transparent(1);
    }
    $self;
}

sub subimage ($self, $x, $y) {
    # Once the tilesize of an image is known, we can slice a subimage
    # from it, given its (x,y)
    return undef unless defined $x && defined $y && defined $self->image && defined $self->tilesize;
    return $self->image->copy->crop(left=>$x*$self->tilesize, top=>$y*$self->tilesize,width=>$self->tilesize,height=>$self->tilesize);
}

1;
