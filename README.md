# simutrans-pak-tools
Simutrans Pak Tools

Displays a variety of reports about the objects in the Simutrans pak. e.g.,

* For each commodity
  - Scan through the range of years
  - Print a flow diagram of industries that involve the commodity

* Vehicle performance statistics
 
* Vehicle timeline consistency check

Example:

    perl show_objects.pl -t ~/simutrans-pak128.britain-Std/text/en.tab \
       ~/simutrans-pak128.britain-Std/boats*/*.dat \
       ~/simutrans-pak128.britain-Std/boats*/*/*.dat

