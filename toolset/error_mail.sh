#!/bin/bash
#
########
#
# Copyright © 2020 @RubenKelevra
#
# LICENSE contains the licensing informations
#
########

set -e

MAILTO=$(cat /etc/aliases | grep -e "^root" | awk '{ print $2 }')
MAILFROM="$HOSTNAME"

unix2dos --quiet "$1"

{
        printf "From:$MAILFROM\r\nTo:$MAILTO\r\nSubject: [REPO2IPFS] Error while running sync on '$HOSTNAME'\r\n\r\n"
        printf "### Failure log:\r\n\r\n"
        cat "$1"
        printf "\r\n\r\n"

} | sendmail $MAILTO

logger --stderr --tag "$0" "[REPO2IPFS] Error mail sent to $MAILTO"
