use lib 'lib';
use Games::Simutrans::Image;
$f = Games::Simutrans::Image->new(file => './t/test_images/player_colors.png')
$f->read({save => 1})
$f->make_transparent;
x $f->image->getchannels;
x $f->image->getpixel(x=>0,y=>0)->rgba;
$f->change_from_player_colors({type => 'std', mapcolor => 141});
$f->change_from_player_colors({type => 'alt', mapcolor => 191, offset => 4, levels => 4});
x $f->image->getpixel(x=>0,y=>0)->rgba;
print "COLOR 0 OK" if (Imager::Color->new(web=>'#008000')->equals(other =>  $f->image->getpixel(x=>0,y=>0)));
$f->write('/tmp/x.png');
