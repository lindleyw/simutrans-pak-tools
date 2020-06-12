#!/usr/bin/env perl
use v5.26;
use feature 'signatures';
no warnings 'experimental';

use Imager;

my $ii = Imager->new;
$ii->read(file => '/home/billl/Documents/games/simutrans/simutrans-pak128.britain/trains/images/lner-v2.png') or die;
# Example:
# $ii->getwidth = 1024
# $ii->getchannels = 3
# $ii->bits = 8
my $newimg=$ii->copy;
my $x_num = 0;
my $y_num = 1;
my $paksize = 128;
# NOTE: Compute $paksize from actual image size $ii->getwidth, $ii->getheight and the maximum
# image (x,y) used within it
$newimg=$ii->crop(left=>$x_num*$paksize,top=>$y_num*$paksize,width=>$paksize,height=>$paksize);

# NOTE: $newimg->getpixel(x=>0,y=>0) =
#0  Imager::Color=SCALAR(0x55af775a06e8)
#   -> 94212113949408
# NOTE: $newimg->getpixel(x=>0,y=>0)->rgba =
# 0  231
# 1  255
# 2  255
# 3  0
# which is the Heritage Transparent color
my $timg=Imager->new(xsize=>128, ysize=>128, channels=>$ii->getchannels);
$timg->box(filled=>1, color=>Imager::Color->new(231,255,255));
my $oimg=$timg->difference(other=>$newimg);

# Example of shearing the image to restore X-axis.
if (0) {
    use Imager::Matrix2d;
    my $m4 = Imager::Matrix2d->shear(y=>(1/2));
    $oimg = $oimg->matrix_transform(matrix=>$m4);
}

sub replace_color ($img) {
    # Inspired by http://www.perlmonks.org/?node_id=497355

    my $rpnexpr = <<'EOS';
x y getp1 !pix
@pix hue !phue @phue from_hue from_hue_thresh + lt @phue from_hue from_hue_thresh - gt and new_hue @phue if
@pix sat
@pix value
@pix alpha
hsva
EOS

    # @pix hue !phue
    # !phue @phue @from_hue == @new_hue @phue ifp
    #  @from_hue == @new_hue @phue ifp


    # to_red to_green to_blue to_alpha rgba @pix ifp

    my %constants;
    # Load values via hash slices
    # @constants{map {"from_$_"} qw{red green blue alpha}} = $from_color->rgba;
    # @constants{map {"to_$_"  } qw{red green blue alpha}} = $to_color  ->rgba;

    return Imager::transform2({ rpnexpr => $rpnexpr,
                                constants => {from_hue => 136, new_hue => 200, from_hue_thresh => 15},
                                channels => 4},
                              $img);
}

sub replace_color_range ($img, $constants) {

    my $rpnexpr = <<'EOS';
x y getp1 !pix
@pix hue !phue
@pix value !pval

@phue from_hue from_hue_thresh + lt @phue from_hue from_hue_thresh - gt and
@pval from_value from_value_thresh + lt @pval from_value from_value_thresh - gt and
and
rr gg bb rgb @pix if

EOS

    $constants->@{qw(rr gg bb aa)}=Imager::Color->new(web=>$constants->{to_color})->rgba;

    return Imager::transform2({ rpnexpr => $rpnexpr,
                                constants => $constants,
                                channels => 4},
                              $img);
}


# Example of changing hue
if (0) {
    $oimg = replace_color($oimg);
} else {

    my $player_colors = {std => ['#244b67', '#395e7c', '#4c7191', '#608a47', '#7497bd', '#88abd3', '#9cbee9', '#b0d2ff'],
                         alt => ['#7b5803', '#8e6f04', '#a18605', '#b49d07', '#c6b408', '#d9cb0a', '#ece20b', '#fff90d']};

    foreach my $value (1..7) {
        # Replace gradations of values of the given hue, with special player colors
        my $v = ($value / 8) + (1/16);
        my $v_threshold = 1/16;
        $oimg = replace_color_range($oimg, {
            from_hue => 120,
            from_hue_thresh => 25,
            from_value => $v,
            from_value_thresh => $v_threshold,
            to_color => $player_colors->{std}->[$value]
        });
    }
}

$oimg->write(file=>'/tmp/transparent.png');

# TODO:
#  - Combine multi-tile images into one
#  - Break images like TileCutter?
#  -

