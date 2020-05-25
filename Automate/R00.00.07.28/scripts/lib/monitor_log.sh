#!/bin/sh

: <<=cut
=script
This script monitor the Screen-Copy log of a specific node. This is 
done by connecting to the dedicated port on the host using ncat.
=version    $Id: monitor_log.sh,v 1.3 2014/12/10 12:32:04 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

ip="$1"     # (M) The ip addres to connect to

idle_time=180    # Timeout in seconds

if [ "$ip" == '' ]; then
    echo "No IP address specified to connect to."
    exit 1
fi

# Test if ncat is installed
which ncat >/dev/null 2>&1
if [ $? != 0 ]; then
    echo "Ncat is not installed cannot monitor this way."
    exit 1
fi

tmp=$(mktemp)
ever_connected=0
while true; do
    echo -n '' >$tmp        # Make sure it is empty even if no stderr is written
    ncat -i "${idle_time}s" $ip 9950 2>$tmp
    if [ $? == 0 -o "$(grep 'Idle timeout expired' $tmp)" != '' ]; then
        ever_connected=1
        attempts=0
    fi
    if [ "$attempt" == '0' ]; then
        if [ "$ever_connected" == '0' ]; then
            echo "Unable to connect, re-trying ..."
        else    
            echo "Lost connection (idle, reboot or finished), re-trying ... "
        fi
    fi
    ((attempt++))
    echo -en "$attempt - "`cat $tmp`"                    \r"
    sleep 5
done
/bin/rm $tmp

exit 0