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

# Usage: ./status_mail.sh <error|recover> <filepath to log>

MAILTO=$(cat /etc/aliases | grep -e "^root" | awk '{ print $2 }')
MAILFROM="$HOSTNAME"


if [ "$1" == "error" ]; then
	unix2dos --quiet "$2"

	{
		printf "From:$MAILFROM\r\nTo:$MAILTO\r\nSubject: [REPO2IPFS] Error while running sync on '$HOSTNAME'\r\n\r\n"
		printf "### Failure log:\r\n\r\n"
		cat "$2"
		printf "\r\n\r\n"

	} | sendmail $MAILTO

	logger --stderr --tag "$0" "[REPO2IPFS] Error mail sent to $MAILTO"
elif [ "$1" == "recover" ]; then
	unix2dos --quiet "$2"

	{
		printf "From:$MAILFROM\r\nTo:$MAILTO\r\nSubject: [REPO2IPFS] Recovering from last error: Successful sync on '$HOSTNAME'\r\n\r\n"
		printf "### Log:\r\n\r\n"
		cat "$2"
		printf "\r\n\r\n"

	} | sendmail $MAILTO

	logger --stderr --tag "$0" "[REPO2IPFS] Recovering from error mail sent to $MAILTO"
elif [ "$1" == "warning" ]; then
	unix2dos --quiet "$2"

	{
		printf "From:$MAILFROM\r\nTo:$MAILTO\r\nSubject: [REPO2IPFS] Warning messages while doing a successful sync on '$HOSTNAME'\r\n\r\n"
		printf "### Log:\r\n\r\n"
		cat "$2"
		printf "\r\n\r\n"

	} | sendmail $MAILTO

	logger --stderr --tag "$0" "[REPO2IPFS] Recovering from error mail sent to $MAILTO"
fi
