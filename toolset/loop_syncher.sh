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

# Usage: ./loop_syncher.sh --store-log


[ ! -f './repo2cluster.sh' ] && exit 1
[ ! -f './error_mail.sh' ] && exit 1

perm_logfile="./loop_syncher.log"

while true; do
	echo -ne "running syncher..."
	tmp_file=$(mktemp "$(basename $0).XXXXXXXXXX" --tmpdir)
	# remove temp file after this script ends
	trap "rm -f '$tmp_file'" 0 2 3 15

	if ! bash ./repo2cluster.sh > "$tmp_file" 2>&1; then
		bash ./error_mail.sh "$tmp_file"
	fi
	if [ "$1" == "--store-log" ]; then
		cat "$tmp_file" >> "$perm_logfile"
	fi
	rm -f "$tmp_file"
	echo -en "\r                                   \r"
	sleep 5
	echo -ne "start sleeping for 50 seconds..."
	sleep 50
	echo -en "\r                                   \r"
	sleep 5
done
