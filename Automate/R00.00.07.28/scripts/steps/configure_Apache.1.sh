#!/bin/sh

: <<=cut
=script
This step configures Apache.
=version    $Id: configure_Apache.1.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

log_info "Configure Apache, defaults are already set"
if [ $GEN_ssl_needed != 0 ]; then
    log_screen "Mobile Messaging supports HTTP and HTTPS. HTTPS is a combination of 
HTTP and SSL/TLS that provides encrypted communication and secure
identification of a network web server. To use HTTPS, you must obtain 
SSL certificates and install them on the web server. You can purchase
SSL certificates from a trusted certificate authority. For more 
information about SSL certificates and Apache, 
refer to http://www.modssl.org/."
    log_info "To use HTTPS, obtain SSL certificates"
fi

return $STAT_passed
