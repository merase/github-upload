#!/bin/sh
#
# This script will show the in progress indicator until is it kill by a SIGINT
#

continue=1
trap continue=0 TERM

indicators='-\|/-\|/'
idx=0
num=${#indicators}
while [ "$continue" == "1" ]; do
    ind="${indicators:$idx:1}"
    if [ "$ind" == '\' ]; then
        ind='\\'
    fi
	echo -en "$ind\b"
#	echo -en "\b"
	((idx++))
	if [ "$idx" -ge "$num" ]; then
		idx=0
	fi
	sleep 1
done


