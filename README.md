# simutrans-pak-tools
Simutrans Pak Tools

Displays a variety of reports about the objects in the Simutrans pak. e.g.,

* For each commodity
  - Scan through the range of years
  - Print a flow diagram of industries that involve the commodity

* Vehicle performance statistics
 
* Vehicle timeline consistency check

## Usage

    -t translation_file   (e.g., path to en.tab)
    -r pak_source_dir     Recursively process *.pak in and under the source_dir
    -v                    Verbose

Example:

    perl show_objects.pl -t ~/simutrans-pak128.britain-Std/text/en.tab \
       -r ~/simutrans-pak128.britain-Std/boats/

## History

Originally [written in 2009 for the Simutrans forum](http://forum.simutrans.com/index.php?topic=2836.msg32268#msg32268)
