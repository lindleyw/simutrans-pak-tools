use lib 'lib';
use Games::Simutrans::Pak;
$p=Pak->new;
$p->path('~/Documents/games/simutrans/simutrans-pak128.britain');
$p->load;
# $p->find_all_images;
# $p->find_image_tile_sizes;
$DB::single = 1;
print "Bork!";
