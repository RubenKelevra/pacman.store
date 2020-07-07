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


[ ! -f './rsync2cluster.sh' ] && exit 1
[ ! -f './status_mail.sh' ] && exit 1

perm_logfile="${HOME}/.rsync2cluster/loop_syncher.log"
ERR_ON_LAST_RUN=0

while true; do
	echo -ne "running syncher..."
	tmp_file=$(mktemp "$(basename $0).XXXXXXXXXX" --tmpdir)
	# remove temp file after this script ends
	trap "rm -f '$tmp_file'" 0 2 3 15

	if ! bash ./rsync2cluster.sh > "$tmp_file" 2>&1; then
		echo ""
		bash ./status_mail.sh "error" "$tmp_file"
		ERR_ON_LAST_RUN=1
	elif [ "$ERR_ON_LAST_RUN" -eq 1 ]; then
		echo ""
		bash ./status_mail.sh "recover" "$tmp_file"
		ERR_ON_LAST_RUN=0
	else #not recovering and no error
		if [ $(grep -E "^Warning: " < "$tmp_file" | wc -l) -gt 0 ]; then
			echo ""
			bash ./status_mail.sh "warning" "$tmp_file"
		fi
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
