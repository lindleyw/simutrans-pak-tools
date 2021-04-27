use lib 'lib';
use Games::Simutrans::Pak;
$p=Games::Simutrans::Pak->new;
$p->path('~/Documents/games/simutrans/simutrans-pak128.britain');
$p->load;

$DB::single = 1;
print "Bork!";
