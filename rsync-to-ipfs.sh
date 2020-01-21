#!/bin/bash
#
########
#
# Copyright © 2014-2019 Florian Pritz <bluewind@xinu.at>
# Copyright © 2019 @RubenKelevra
#
# LICENSE contains the licensing informations
#
########

# simple script to convert a remote 'archlinux package mirror' to a lineary pacman cache
# on ipfs-mfs with ipfs-cluster pinning

# Directory where the repo is permanently locally mirrored as rsync target. Example: /srv/repo
rsync_mirror=""

# temporary rsync storage (on same storage as rsync_mirror
# Example: /srv/tmp
rsync_tmp=""

# Lockfile path
lock="/a/path/to/lock/file/rsync-to-ipfs.sh.lck"

#Logfile path
log="/a/path/to/log/file/rsync-to-ipfs.log"

# rsync url
rsync_url='rsync://abc.host/subfolder/'

# http/https url to the lastupdate file on the same server, to skip unnecessary rsync syncs 
lastupdate_url=''

#### END CONFIG

[ ! -d "${rsync_mirror}" ] && mkdir -p "${rsync_mirror}"
[ ! -d "${rsync_tmp}" ] && mkdir -p "${rsync_tmp}"

exec 9>"${lock}"
flock -n 9 || exit

rsync_cmd() {
	local -a cmd=(rsync -rtlH --quiet --safe-links --delete-after "${VERBOSE}" "--log-file=${log}" --log-file-format='%i %n%L' "--timeout=600" "--contimeout=60" -p \
		--delay-updates --no-motd "--temp-dir=${rsync_tmp}")
	"${cmd[@]}" "$@"
}

# only run when there are changes
if [[ -f "$rsync_mirror/lastupdate" ]] && diff -b <(curl -Ls "$lastupdate_url") "$rsync_mirror/lastupdate" >/dev/null; then
	exit 0
fi

rsync_cmd \
	--exclude='*.links.tar.gz*' \
	--exclude='/community' \
	--exclude='/community-staging' \
	--exclude='/community-testing' \
	--exclude='/core' \
	--exclude='/extra' \
	--exclude='/gnome-unstable' \
	--exclude='/kde-unstable' \
	--exclude='/lastsync' \
	--exclude='/multilib' \
	--exclude='/multilib-staging' \
	--exclude='/multilib-testing' \
	--exclude='/staging' \
	--exclude='/testing' \
	--exclude='/other' \
	--exclude='/sources' \
	--exclude='/iso' \
	--exclude='/pool/packages/*.sig' \
	--exclude='/pool/community/*.sig' \
	--exclude='/pool/community/Checking' \
	"${rsync_url}" \
	"${rsync_mirror}"


#echo "Last sync was $(date -d @$(cat ${target}/lastsync))"
