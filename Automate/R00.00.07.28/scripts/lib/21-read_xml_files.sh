#!/bin/sh

: <<=cut
=script
This script is capable of simple reading paramters out of XML files.
=script_note
This is not yet rocket science and could need extending in the future.
it does not (yet) make use of external tools whihc would require a dependency.
=version    $Id: 21-read_xml_files.sh,v 1.1 2015/10/09 09:02:43 fkok Exp $
=author     Frank.Kok@newnet.com

=feat merge xml files
Capability to read multiple input files and create one merged file. Un-Resolvable
conflicts are reported.

=feat add xml data
XML data can be added before writing out the merged file.

=cut

readonly xml_f_reg='[a-zA-Z0-9_/\-\.]+'  # The field regular expression.


: <<=cut
=func_int
Read a specific set of xml from a section.
=func_note
This does not include sub-paths so the given section has to be unique within the
file. This for now is the cheapest and currenlty allowed option!
=stdout
The values, if none then empty if multiple then every line is a value.
=cut
function read_xml_values() {
    local file="$1"     # (M) The file to read
    local sect="$2"     # (M) The section to filter out (e.g. tpconfig, fxferfile)
    local var="$3"      # (M) The variable to filter out
    # It is build is a piped satement which filter all last subsection to the wanted and then find the variable
    # * get is all on one line
    # * al > are put a ne line (end of a section
    # * the section is filtered
    # * the full variable including value is filters
    # * then filter value and remove the "
    cat "$file" | tr '\n' ' ' | sed -e 's/>/>\n/g' | grep "$sect" | $CMD_ogrep "$var *= *\"$xml_f_reg\""  | $CMD_ogrep "\"$xml_f_reg\"" | $CMD_ogrep "$xml_f_reg"
}

