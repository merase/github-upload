#!/bin/sh

: <<=cut
=script
This script contains simple helper functions related which are related to
textual trick stuff.
=version    $Id: 20-modify_text_files.sh,v 1.12 2017/12/14 13:59:23 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
Test if the text is found in a file returns and give additional info msg.
=func_note
Currently a simple grep is used to find the text so no keep the grep regex
rules in mind!.
=set TEXT_found
The line with the found text (in case needed)
=ret
0 if no match found or file not existing (and thus not found) or 1 in case
the text is found.
=cut
function text_found() {
    local file="$1"     # (M) The file to check
    local match="$2"    # (M) The text to find in the find file

    TEXT_found=''
    if [ -r "$file" ]; then
        TEXT_found=$(grep -m 1 -e "$match" "$file")
    fi
    if [ "$TEXT_found" != '' ]; then
        log_info "Info: the text '$match' already existed in '$file'"
        return 1
    fi
    return 0
}

: <<=cut
=func_frm
Substitutes all matched text by other text. So make sure the
find (regex) is unique.
=func_note
sed is used for doing this substitute. 
See sed for info on regex
=cut
function text_substitute() {
    local file="$1"     # (M) File to substitue in.
    local text="$2"     # (M) Text to find (may be regex).
    local replace="$3"  # (M) Text to replace matches with.

    [ -z help ] && show_short="Substitute all matched text by some other text"
    
    local tmp="$(mktemp)"
    cmd '' $CMD_cp -L $file $tmp

    local slash=`echo "$text$replace" | $CMD_ogrep '/'`
    if [ "$slash" == '' ]; then     # No slashes, use normal methods
        sed "s/$text/$replace/" $tmp > $file
    else 
        local pipe=`echo "$text$replace" | $CMD_ogrep '\|'`
        if [ "$pipe" == '' ]; then  # Slashes assume path use |
            sed "s|$text|$replace|" $tmp > $file
        else
            sed "s~$text~$replace~" $tmp > $file
        fi
    fi    
    check_success "Substitute '$text' with '$replace' in file '$file'" "$?"

    remove_temp $tmp
}

: <<=cut
=func_frm
Add a line to a file which is only added if not existing.
=return
1 the line was added (so not found), 0 it was not added (so match already found)
=cut
function text_add_line() {
    local file="$1"     # (M) The file to add the line to.
    local line="$2"     # (M) The line(s) to add (if not found yet).
    local match="$3"    # (O) Match for existence, if omitted then I<line> is searched for.

    match=${match:-"$line"}

    [ -z help ] && show_short="Add a text line in a file if the line does not exists"
    [ -z help ] && [ "$3" == '' ] && show_pars[3]=''    # Don' show default in this case
    
    text_found "$file" "$match"
    if [ $? == 0 ]; then
        echo "$line" >> $file
        check_success "Added line '$line' to '$file'" "$?"
        return 1
    fi
    return 0
}

: <<=cut
=func_frm
Add a line to a file which is only added if not existing. It will be added at the
end or after a a specific line if found.
is slightly tricky 
=cut
function text_add_line_after() {
    local file="$1"     # (M) The file to add the line to.
    local line="$2"     # (M) The line(s) to add (if not found yet).
    local after="$3"    # (O) The line to add after, if empty then text_add_lien will be used.
    local match="$4"    # (O) Match for existence, if omitted then I<line> is searched for.

    match=${match:-"$line"}

    [ -z help ] && show_short="Add a text line in a file after a specific line, but only if the line does not exists"
    [ -z help ] && [ "$4" == '' ] && show_pars[4]=''    # Don' show default in this case

    if [ "$after" == '' ]; then
        text_add_line "$file" "$line" "$match"
    else
        after=$(echo "$after" | $CMD_sed -e 's|/|\\/|g')   # Catch '/' problem
        text_found "$file" "$match" "add_line_after"
        if [ $? == 0 ]; then
            cmd_hybrid 'add after' "$CMD_sed -i '/$after/a\\$line' $file"
        fi
    fi
}

: <<=cut
=func_frm
Replace or add a line if not existing yet.
=cut
function text_replace_or_add_line() {
    local file="$1"     # (M) The file to add the line to.
    local line="$2"     # (M) The line(s) to add (if not found yet).
    local match="$3"    # (O) Match for replace (should match full replaced text), if omitted then I<line> is searched for.

    match=${match:-"$line"}

    [ -z help ] && show_short="Replace the matched line in the file or adds if not found."
    [ -z help ] && [ "$3" == '' ] && show_pars[3]=''    # Don' show default in this case
    
    text_found "$file" "$match" 
    if [ $? == 0 ]; then
        echo "$line" >> "$file"
        check_success "Added, no replace, line '$line' to '$file'" "$?"
    else
        text_substitute "$file" "$match" "$line"
    fi
}

: <<=cut
=func_frm
Removes a lone from a file if it matches. Make sure the match is unique enough!
=func_note
The match should not contain the slash '/' or escape it which is workable for now.
Perhaps that has to be changed in the future.
=cut
function text_remove_line() {
    local file="$1"     # (M) The file to remove the line from.
    local match="$2"    # (M) Match for removal. may contain sed regex, no unescaped /

    [ -z help ] && show_short="Removes the line matching the given text."

    if [ -r $file ]; then
        sed -i".bak" "/$match/d" $file
        check_success "Removal of line matching '$match' from '$file'" "$?"
    else
        log_info "Nothing ($match) to remove as '$file' does not exist."
    fi
}

: <<=cut
=func_frm
Make a line commented (with #) or uncomments it. A line is recognized by
first part o the commented/uncommented section. Theoretically multiple lines
can be changed if the line matches.
=func_note
If the file does not exist then this is silently ignored as there is nothing
to change. If the line does not match then nothing is changed as well.
=cut
function text_change_comment() {
    local what="$1"         # (M) either enable the line = uncomment or disable the line = comment
    local match="$2"        # (M) The start of the line to match
    local file="$3"         # (M) The file to make the changes in
    local comment_sym="$4"  # (O) The comment symbol, defaults to '#'

    comment_sym=${comment_sym:-'#'}

    [ -z help ] && show_conditional=1 
    [ -z help ] && show_cond['enable']="Uncomment all lines starting with the 'match' string by removing the '$comment_sym' character"
    [ -z help ] && show_cond['disable']="Comment all lines starting with the 'match' string by adding the '$comment_sym' character"
    [ -z help ] && show_cond['$what']="Missing parameter <what> for text_change_comment"
    [ -z help ] && show_pars[4]=''       # Ignore paremeter it is shown above

    if [ ! -w "$file" ]; then return; fi
    case "$what" in
        enable ) cmd_hybrid "uncomment lines with '$match'" "$CMD_sed -i 's|^ *$comment_sym *\($match\)|\1|' $file"; ;;
        disable) cmd_hybrid "comment lines with '$match'"   "$CMD_sed -i 's|^ *\($match\)|$comment_sym\1|'   $file"; ;;
        *) log_exit "Wrong parameter given, check programming!"; ;;
    esac    
}
