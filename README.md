# simutrans-pak-tools

## show_objects.pl

Displays a variety of reports about the objects in the Simutrans pak. e.g.,

* For each commodity
  - Scan through the range of years
  - Print a flow diagram of industries that involve the commodity

* Vehicle performance statistics
 
* Vehicle timeline consistency check

### Usage

    -t translation_file   (e.g., path to en.tab)
    -r pak_source_dir     Recursively process *.pak in and under the source_dir
    -v                    Verbose

Example:

    perl show_objects.pl -t ~/simutrans-pak128.britain-Std/text/en.tab \
       -r ~/simutrans-pak128.britain-Std/boats/

### History

Originally [written in 2009 for the Simutrans forum](http://forum.simutrans.com/index.php?topic=2836.msg32268#msg32268)

## alter_hue

Changes one or more hues in a PNG file (as used when authoring Simutrans
paks) to other hues, or to player color gradients or alternate color
gradients.

The desired changes are specified as a single comma-separated list,
without internal spaces.  Each component may be of the forms:

    [HUE][+TOLERANCE]-[NEW_HUE|m MAPCOLOR|p|a]

The following switches are available:

    -i <input file>
    -o <output file>
    -p <paksize>
    -x <crop single X offset>
    -y <crop single y offset>
    -M   lists the hues of all (bright) mapcolors [7, 15, etc.]
         and exits

Example:

    ./alter_hue -i INFILE -o OUTFILE 20+7-m100,40-180,60-p

(assuming the alter_hue program file has the +x (execute) attribute)
which will change:

* hue 20 ± 7 to hue of mapcolor 100,
* hue 40 ± 10 [using the default 10] to hue 180, and
* hue 60 ± 10 to special player colors.

Alternately color map can be, for example:   `p-m70,a-m25`

which would change:

* Player color gradation to correspond to range containing mapcolor 70 (i.e., 64..71) and

* Alternate player-color gradation to mapcolor 25 (i.e., 24..31).

Note that Hue is specified in the HSV system. If your modifications
seemingly have no effect, please verify that your graphic editing
program is displaying HSV.

### Requires

Only core Perl, plus the Imager module (try: `cpanm Imager`)
