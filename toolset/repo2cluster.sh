#!/bin/bash
#
########
#
# Copyright © 2020 @RubenKelevra
#
# Based on work from:
# Copyright © 2014-2019 Florian Pritz <bluewind@xinu.at>
#   See for original script:
#   https://git.archlinux.org/infrastructure.git/tree/roles/syncrepo/files/syncrepo-template.sh
#
# LICENSE contains the licensing informations
#
########

set -e


# simple script to convert a remote 'archlinux package mirror' to a
# lineary pacman cache on ipfs-mfs with ipfs-cluster pinning
#
# db files are stored in the db subfolder
#
# available arguments:
# --force-full-add = will add all files again to ipfs even if locally the
#                    ipfs-mfs folders already exist

# dependencies:
# - dos2unix
# - ipfs-cluster-ctl
# - a running ipfs-cluster-service
# - a running ipfs
# - more than twice the storage currently in the repo (deduplicated)
# - "$ipfs_mount" and "$ipns_mount" needs to be unmounted to run this script
# - need to be run with the same user account which runs the ipfs daemon and the ipfs-cluster-service daemon

### config ###

# linux distribution identifier
dist_id='arch'

# architecture identifier
arch_id='x86_64'

# repo identifier
repo_id='default'

# main config

# Directory where the repo is permanently locally mirrored as rsync target.
rsync_target="/var/lib/ipfs/repo-${dist_id}-${arch_id}-${repo_id}/repo/"

# Lockfile path
lock="/var/lib/ipfs/repo2cluster/${dist_id}-${arch_id}-${repo_id}.lock"

#Logfile filename
rsync_log="/var/lib/ipfs/repo2cluster/${dist_id}-${arch_id}-${repo_id}.log"

#Logfile archive file
rsync_log_archive="/var/lib/ipfs/repo2cluster/${dist_id}-${arch_id}-${repo_id}_archive.log"

# rsync url
rsync_url='rsync://mirror.f4st.host/archlinux/'

# http/https url to the lastupdate file on the same server, to skip unnecessary rsync syncs
lastupdate_url='https://mirror.f4st.host/archlinux/lastupdate'

# ipfs-mfs repository folder + domain
ipfs_pkg_folder='pkg.pacman.store'

# ipfs-mfs iso repository folder + domain
ipfs_iso_folder='iso.pacman.store'

# folder where the ipns is mounted
ipns_mount='/mnt/ipns'

# folder where the ipfs is mounted
ipfs_mount='/mnt/ipfs'

cluster_replication_min="2"
cluster_replication_max="10"

loki="12D3KooWMY6rUugH6M2vF2qhp75P2RZuy34UNuyTzDDaoMYnCEuf"
vidar="12D3KooWRUayEaCReaqQiUPRs3CBjtkQd7XgXN5fFThGXSeQQnze"



#### END CONFIG

# get lock or exit
exec 9>"${lock}"
flock -n 9 || exit

# local functions

function fail {
	[ -n "$3" ] && [ "$3" == '-n' ] && printf '\n'
	[ -n "$3" ] && [ "$3" == '-2n' ] && printf '\n\n'
    printf 'Error: %s\n' "$1" >&2
    exit "${2-1}"
}

function rsync_cmd() {
	local -a cmd=(rsync -rtlH -LK --safe-links --delete-excluded --delete --delete-during --inplace "--log-file=${rsync_log}" "--timeout=600" "--contimeout=60" -p \
		 --no-motd)

	if stty &>/dev/null; then
		cmd+=(-h -v --progress)
	else
		cmd+=(--quiet)
	fi

	"${cmd[@]}" "$@"
}

function pin_rootfolder_to_cluster() {
	# expect 1: to be valid cid
	# expect 2: to be the usual name of a folder
	# expect 3: to be a timestamp

	local _cluster_replication_min="$cluster_replication_min"
	local _cluster_replication_max="$cluster_replication_max"
	local _expire="$cluster_pin_rootfolder_expire"

	local _cid="$1"
	local _name="$2"
	local _timestamp="$3"

	[ -z "$_cid" ] && fail "pin_rootfolder_to_cluster: cid was empty" 230
	[ -z "$_name" ] && fail "pin_rootfolder_to_cluster: name was empty. CID: $_cid" 231
	[ -z "$_timestamp" ] && fail "pin_rootfolder_to_cluster: timestamp was empty. CID: $_cid" 232

	_name="$_name frozen@$_timestamp"

	if ! ipfs-cluster-ctl pin add --no-status --expire-in "$_expire" --name "$_name" --replication-min="$_cluster_replication_min" --replication-max="$_cluster_replication_max" "$_cid" > /dev/null; then
		fail "ipfs-cluster-ctl returned an error while running pin_rootfolder_to_cluster on the cid: '$_cid', name: '$_name'" 214
	fi
	return 0
}

function add_expiredate_to_clusterpin() {
	local _cid="$1"

	if ! ipfs-cluster-ctl pin rm --no-status "$_cid" > /dev/null; then
		echo "Warning: ipfs-cluster-ctl returned an error while removing a cluster pin: cid: '$_cid'"
	fi

	return 0
}

function add_file_to_cluster() {
	local _cluster_replication_min="$cluster_replication_min"
	local _cluster_replication_max="$cluster_replication_max"
	local _new_cid=""

	if [ "$1" == "pkg" ]; then
		# expect 2: to be repository-name
		# expect 3: to be the filename
		local _filepath="${rsync_target}$2/os/$arch_id/$3"
		local _name="$ipfs_repo_folder/$2/$3"
	elif [ "$1" == "db" ]; then
		# expect 2: to be repository-name
		local _filepath="${rsync_target}$2/os/$arch_id/$2.db"
		local _name="$ipfs_repo_folder/db/$2.db"
	elif [ "$1" == "iso" ]; then
		# expect 2: to be a foldername
		# expect 3: to be a filename
		local _filepath="${rsync_target}iso/$2/$3"
		local _name="$ipfs_iso_folder/$distarchrepo_path/$2/$3"
	elif [ "$1" == "note" ]; then
		# expect 2: a full path
		# expect 3: a name
		local _filepath="$2"
		local _name="$3"
	else
		fail "unexpected first argument '$1' on add_file_to_cluster()" 200
	fi

	if [ ! -f "$_filepath" ]; then
		echo "Warning: Skipping file because it could not be located: '$_filepath'"  >&2
		return 1
	fi

	if ! _new_cid=$(ipfs-cluster-ctl add --local --cid-version 1 --allocations "$loki,$vidar" --quieter --name "$_name" --replication-min="$_cluster_replication_min" --replication-max="$_cluster_replication_max" "$_filepath"); then
		fail "ipfs-cluster-ctl returned an error while adding a file to the cluster filetype: '$1' name: '$_name' filepath: '$_filepath'" 201
	fi

	echo "$_new_cid"
}

# state variables
FULL_ADD=0
RECOVER=0

# simple one argument decoding

if [ -n "$1" ]; then
	if [ "$1" == '--force-full-add' ]; then
		echo "running full add..."
		FULL_ADD=1
	else
		fail "unexpected first argument" 150
	fi
fi

# check config

[ -z "$rsync_target" ] && fail "rsync target dir config string is empty" 10
[ -z "$lock" ] && fail "lock file config string is empty" 12
[ -z "$rsync_log" ] && fail "rsync file config string is empty" 13
[ -z "$rsync_log_archive" ] && fail "rsync log archive file config string is empty" 14
[ -z "$rsync_target" ] && fail "rsync target dir config string is empty" 15
[ -z "$rsync_url" ] && fail "rsync url config string is empty" 16
[ -z "$lastupdate_url" ] && fail "lastupdate url config string is empty" 17
[ -z "$ipfs_pkg_folder" ] && fail "repo folder (IPFS) config string is empty" 18
[ -z "$dist_id" ] && fail "distribution identifier config string is empty" 20
[ -z "$arch_id" ] && fail "architecture identifier config string is empty" 21
[ -z "$repo_id" ] && fail "repository identifier config string is empty" 22
[ -z "$cluster_replication_min" ] && fail "cluster replication max config string is empty" 26
[ -z "$cluster_replication_max" ] && fail "cluster replication min config string is empty" 27
[ -z "$ipfs_iso_folder" ] && fail "iso folder (IPFS) config string is empty" 28

[ -d "$ipns_mount" ] || fail "ipns mount dir could not be located" 50
[ -d "$ipfs_mount" ] || fail "ipfs mount dir could not be located" 51

# check/create directories
[ ! -d "${rsync_target}" ] && mkdir -p "${rsync_target}"

# check if $ipfs_mount / $ipns_mount are mounted
[ "$(mount -l | grep -c "/dev/fuse on $ipns_mount type fuse")" -eq 1 ] && fail "ipns mount dir is mounted" 52
[ "$(mount -l | grep -c "/dev/fuse on $ipfs_mount type fuse")" -eq 1 ] && fail "ipfs mount dir is mounted" 53

# create local vars:
distarchrepo_path="$dist_id/$arch_id/$repo_id"
ipfs_repo_folder="$ipfs_pkg_folder/$distarchrepo_path"
ipfs_db_folder="$ipfs_repo_folder/db"
ipfs_pkg_cache_folder="$ipfs_repo_folder/cache"

#check for ipfs-mfs folders

if [ $FULL_ADD -eq 1 ]; then
	echo "creating empty ipfs folder for pkg..."
	ipfs files rm -r "/$ipfs_pkg_folder" > /dev/null 2>&1 || true
	ipfs files mkdir --cid-version 1 "/$ipfs_pkg_folder" > /dev/null 2>&1 || fail "ipfs folder for pkg couldn't be created" 100 -n
elif ! ipfs files stat "/$ipfs_pkg_folder" > /dev/null 2>&1; then
	fail "ipfs folder for pkg does not exist, make sure to clear the cluster pins, remove all folders and run with --force-full-add again" 300 -n
fi

if [ $FULL_ADD -eq 1 ]; then
	echo "creating empty ipfs subfolder (down to db) for pkg..."
	ipfs files mkdir -p --cid-version 1 "/$ipfs_db_folder" > /dev/null 2>&1 || fail "ipfs subfolder (down to db) for pkg couldn't be created" 101 -n
elif  ! ipfs files stat "/$ipfs_db_folder" > /dev/null 2>&1; then
	fail "ipfs subfolder (down to db) does not exist, make sure to clear the cluster pins, remove all folders and run with --force-full-add again" 301 -n
fi

if [ $FULL_ADD -eq 1 ]; then
	echo "creating empty ipfs folder for pkg cache..."
	ipfs files mkdir -p --cid-version 1 "/$ipfs_pkg_cache_folder" > /dev/null 2>&1 || fail "ipfs folder for pkg cache couldn't be created" 101 -n
elif  ! ipfs files stat "/$ipfs_pkg_cache_folder" > /dev/null 2>&1; then
	fail "ipfs folder for pkg cache does not exist, make sure to clear the cluster pins, remove all folders and run with --force-full-add again" 301 -n
fi

if [ $FULL_ADD -eq 1 ]; then
	echo "creating empty ipfs folder for iso..."
	ipfs files rm -r "/$ipfs_iso_folder" > /dev/null 2>&1 || true
	ipfs files mkdir --cid-version 1 "/$ipfs_iso_folder" > /dev/null 2>&1 || fail "ipfs folder for iso couldn't be created" 104 -n
elif ! ipfs files stat "/$ipfs_iso_folder" > /dev/null 2>&1; then
	fail "ipfs folder for iso does not exist, make sure to clear the cluster pins, remove all folders and run with --force-full-add again" 304 -n
fi

# print a warning if the previous process haven't deleted the log of rsync
#   force a rsync and a ipfs add of all files again, to ensure were up to date
if [ $FULL_ADD -eq 0 ]; then
	if [ -f "$rsync_log" ]; then
		echo "Warning: Last sync with ipfs incomplete, reread the last transmission log" >&2
		RECOVER=1
	fi
else
	RECOVER=0
fi

#don't update when recovering from the last update
if [ "$RECOVER" -eq 0 ]; then

	# only run when there are changes
	if [[ -f "${rsync_target}lastupdate" ]] && diff -b <(curl -Ls "$lastupdate_url") "${rsync_target}lastupdate" >/dev/null; then
		[ $FULL_ADD -eq 1 ] || exit 0 # only exit here if we should not do a full add
	fi

	rsync_cmd \
		--include="/community/os/${arch_id}/community.db" \
		--exclude="/community/os/${arch_id}/*.db" \
		--exclude="/community/os/${arch_id}/community.db*" \
		--exclude="/community/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/community/os/${arch_id}/community.links*" \
		--exclude="/community/os/${arch_id}/community.files*" \
		--exclude="/community/os/${arch_id}/community.abs*" \
		--exclude="/community/os/${arch_id}/local" \
		--include="/community/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/community/os/${arch_id}/*-any.pkg.*" \
		--exclude="/community/os/${arch_id}/*" \
		--include="/community-staging/os/${arch_id}/community-staging.db" \
		--exclude="/community-staging/os/${arch_id}/*.db" \
		--exclude="/community-staging/os/${arch_id}/community-staging.db*" \
		--exclude="/community-staging/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/community-staging/os/${arch_id}/community-staging.links*" \
		--exclude="/community-staging/os/${arch_id}/community-staging.files*" \
		--exclude="/community-staging/os/${arch_id}/community-staging.abs*" \
		--exclude="/community-staging/os/${arch_id}/local" \
		--include="/community-staging/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/community-staging/os/${arch_id}/*-any.pkg.*" \
		--exclude="/community-staging/os/${arch_id}/*" \
		--include="/community-testing/os/${arch_id}/community-testing.db" \
		--exclude="/community-testing/os/${arch_id}/*.db" \
		--exclude="/community-testing/os/${arch_id}/community-testing.db*" \
		--exclude="/community-testing/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/community-testing/os/${arch_id}/community-testing.links*" \
		--exclude="/community-testing/os/${arch_id}/community-testing.files*" \
		--exclude="/community-testing/os/${arch_id}/community-testing.abs*" \
		--exclude="/community-testing/os/${arch_id}/local" \
		--include="/community-testing/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/community-testing/os/${arch_id}/*-any.pkg.*" \
		--exclude="/community-testing/os/${arch_id}/*" \
		--include="/core/os/${arch_id}/core.db" \
		--exclude="/core/os/${arch_id}/*.db" \
		--exclude="/core/os/${arch_id}/core.db*" \
		--exclude="/core/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/core/os/${arch_id}/core.links*" \
		--exclude="/core/os/${arch_id}/core.files*" \
		--exclude="/core/os/${arch_id}/core.abs*" \
		--exclude="/core/os/${arch_id}/local" \
		--include="/core/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/core/os/${arch_id}/*-any.pkg.*" \
		--exclude="/core/os/${arch_id}/*" \
		--include="/extra/os/${arch_id}/extra.db" \
		--exclude="/extra/os/${arch_id}/*.db" \
		--exclude="/extra/os/${arch_id}/extra.db*" \
		--exclude="/extra/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/extra/os/${arch_id}/extra.links*" \
		--exclude="/extra/os/${arch_id}/extra.files*" \
		--exclude="/extra/os/${arch_id}/extra.abs*" \
		--exclude="/extra/os/${arch_id}/local" \
		--include="/extra/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/extra/os/${arch_id}/*-any.pkg.*" \
		--exclude="/extra/os/${arch_id}/*" \
		--include="/gnome-unstable/os/${arch_id}/gnome-unstable.db" \
		--exclude="/gnome-unstable/os/${arch_id}/*.db" \
		--exclude="/gnome-unstable/os/${arch_id}/gnome-unstable.db*" \
		--exclude="/gnome-unstable/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/gnome-unstable/os/${arch_id}/gnome-unstable.links*" \
		--exclude="/gnome-unstable/os/${arch_id}/gnome-unstable.files*" \
		--exclude="/gnome-unstable/os/${arch_id}/gnome-unstable.abs*" \
		--exclude="/gnome-unstable/os/${arch_id}/local" \
		--include="/gnome-unstable/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/gnome-unstable/os/${arch_id}/*-any.pkg.*" \
		--exclude="/gnome-unstable/os/${arch_id}/*" \
		--include="/kde-unstable/os/${arch_id}/kde-unstable.db" \
		--exclude="/kde-unstable/os/${arch_id}/*.db" \
		--exclude="/kde-unstable/os/${arch_id}/kde-unstable.db*" \
		--exclude="/kde-unstable/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/kde-unstable/os/${arch_id}/kde-unstable.links*" \
		--exclude="/kde-unstable/os/${arch_id}/kde-unstable.files*" \
		--exclude="/kde-unstable/os/${arch_id}/kde-unstable.abs*" \
		--exclude="/kde-unstable/os/${arch_id}/local" \
		--include="/kde-unstable/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/kde-unstable/os/${arch_id}/*-any.pkg.*" \
		--exclude="/kde-unstable/os/${arch_id}/*" \
		--include="/multilib/os/${arch_id}/multilib.db" \
		--exclude="/multilib/os/${arch_id}/*.db" \
		--exclude="/multilib/os/${arch_id}/multilib.db*" \
		--exclude="/multilib/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/multilib/os/${arch_id}/multilib.links*" \
		--exclude="/multilib/os/${arch_id}/multilib.files*" \
		--exclude="/multilib/os/${arch_id}/multilib.abs*" \
		--exclude="/multilib/os/${arch_id}/local" \
		--include="/multilib/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/multilib/os/${arch_id}/*-any.pkg.*" \
		--exclude="/multilib/os/${arch_id}/*" \
		--include="/multilib-staging/os/${arch_id}/multilib-staging.db" \
		--exclude="/multilib-staging/os/${arch_id}/*.db" \
		--exclude="/multilib-staging/os/${arch_id}/multilib-staging.db*" \
		--exclude="/multilib-staging/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/multilib-staging/os/${arch_id}/multilib-staging.links*" \
		--exclude="/multilib-staging/os/${arch_id}/multilib-staging.files*" \
		--exclude="/multilib-staging/os/${arch_id}/multilib-staging.abs*" \
		--exclude="/multilib-staging/os/${arch_id}/local" \
		--include="/multilib-staging/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/multilib-staging/os/${arch_id}/*-any.pkg.*" \
		--exclude="/multilib-staging/os/${arch_id}/*" \
		--include="/multilib-testing/os/${arch_id}/multilib-testing.db" \
		--exclude="/multilib-testing/os/${arch_id}/*.db" \
		--exclude="/multilib-testing/os/${arch_id}/multilib-testing.db*" \
		--exclude="/multilib-testing/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/multilib-testing/os/${arch_id}/multilib-testing.links*" \
		--exclude="/multilib-testing/os/${arch_id}/multilib-testing.files*" \
		--exclude="/multilib-testing/os/${arch_id}/multilib-testing.abs*" \
		--exclude="/multilib-testing/os/${arch_id}/local" \
		--include="/multilib-testing/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/multilib-testing/os/${arch_id}/*-any.pkg.*" \
		--exclude="/multilib-testing/os/${arch_id}/*" \
		--include="/staging/os/${arch_id}/staging.db" \
		--exclude="/staging/os/${arch_id}/*.db" \
		--exclude="/staging/os/${arch_id}/staging.db*" \
		--exclude="/staging/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/staging/os/${arch_id}/staging.links*" \
		--exclude="/staging/os/${arch_id}/staging.files*" \
		--exclude="/staging/os/${arch_id}/staging.abs*" \
		--exclude="/staging/os/${arch_id}/local" \
		--include="/staging/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/staging/os/${arch_id}/*-any.pkg.*" \
		--exclude="/staging/os/${arch_id}/*" \
		--include="/testing/os/${arch_id}/testing.db" \
		--exclude="/testing/os/${arch_id}/*.db" \
		--exclude="/testing/os/${arch_id}/testing.db*" \
		--exclude="/testing/os/${arch_id}/*.pkg.*.sig" \
		--exclude="/testing/os/${arch_id}/testing.links*" \
		--exclude="/testing/os/${arch_id}/testing.files*" \
		--exclude="/testing/os/${arch_id}/testing.abs*" \
		--exclude="/testing/os/${arch_id}/local" \
		--include="/testing/os/${arch_id}/*-${arch_id}.pkg.*" \
		--include="/testing/os/${arch_id}/*-any.pkg.*" \
		--exclude="/testing/os/${arch_id}/*" \
		--exclude='*.links.tar*' \
		--exclude='md5sums.txt' \
		--exclude='*.torrent' \
		--exclude='/other' \
		--exclude='/sources' \
		--exclude='/lastsync' \
		--exclude='/iso/latest' \
		--exclude='/iso/archboot' \
		--exclude='/iso/*/arch' \
		--include='/iso/*' \
		--exclude='/pool' \
		--include='/lastupdate' \
		"${rsync_url}" \
		"${rsync_target}"
fi

if [ $FULL_ADD -eq 0 ]; then
	#fix broken rsync logs
	dos2unix -q -c mac "$rsync_log"
else #delete rsync log (we won't use it anyway)
	rm -f "$rsync_log"
	sync
fi


if [ $FULL_ADD -eq 0 ]; then #diff update mechanism

	#parsing rsync log

	#deleted files
	while IFS= read -r -d $'\n' deleted_file; do
		if [[ $deleted_file = *'.pkg.'* ]]; then #that's a pkg
			pkg_name=$(echo "$deleted_file" | cut -d'/' -f4)
			pkg_repo_folder=$(echo "$deleted_file" | cut -d'/' -f1)
			pkg_dest_path="/$ipfs_repo_folder/$pkg_repo_folder/$pkg_name"
			pkg_pacmanstore_dest_path="/$ipfs_pkg_cache_folder/$pkg_name"
			if ! pkg_old_cid=$(ipfs files stat --hash "$pkg_dest_path" 2>/dev/null ); then
				echo "Warning: the pkg file '$deleted_file' was already deleted on IPFS" >&2
				if ! pkg_old_cid=$(ipfs files stat --hash "$pkg_pacmanstore_dest_path" 2>/dev/null ); then
					echo "Warning: the pkg file '$deleted_file' was already deleted in pkg cache folder on IPFS" >&2
					continue
				fi
			fi
			add_expiredate_to_clusterpin "$pkg_old_cid" 'pkg' "$pkg_repo_folder" "$pkg_name"

			ipfs files rm "$pkg_dest_path" || true & # ignore if the file doesn't exist
			ipfs files rm "$pkg_pacmanstore_dest_path" || true # ignore if the file doesn't exist
			unset pkg_name pkg_dest_path pkg_old_cid pkg_repo_folder pkg_pacmanstore_dest_path

		elif [ "${deleted_file:0:4}" == 'iso/' ]; then #that's everything in iso/
			iso_file_name=$(echo "$deleted_file" | cut -d'/' -f3)
			iso_file_folder=$(echo "$deleted_file" | cut -d'/' -f2)
			iso_dest_path="/$ipfs_iso_folder/$distarchrepo_path/$iso_file_folder/$iso_file_name"
			if ! iso_old_cid=$(ipfs files stat --hash "$iso_dest_path" 2>/dev/null ); then
				echo "Warning: the file in iso/ '$deleted_file' was already deleted on IPFS" >&2
				continue
			fi
			if [ -z "$iso_file_name" ]; then # that's the empty folder
				ipfs files rm -r "$iso_dest_path"
			else
				add_expiredate_to_clusterpin "$iso_old_cid" 'iso' "$iso_file_folder" "$iso_file_name"
				ipfs files rm "$iso_dest_path"
			fi
			unset iso_file_name iso_file_folder iso_dest_path iso_old_cid

		elif [ "${deleted_file: -3}" == '.db' ]; then # that's a database file
			db_repo_name=$(echo "$deleted_file" | cut -d'/' -f1)
			db_dest_path="/$ipfs_db_folder/${db_repo_name}.db"
			db_dest_path_pkg="/$ipfs_repo_folder/$db_repo_name/${db_repo_name}.db"
			if ! db_old_cid=$(ipfs files stat --hash "$db_dest_path" 2>/dev/null ); then
				echo "Warning: the .db-file '$deleted_file' was already deleted on IPFS" >&2
				continue
			fi
			add_expiredate_to_clusterpin "$db_old_cid" 'db' "$db_repo_name"
			ipfs files rm "$db_dest_path"
			ipfs files rm "$db_dest_path_pkg" || true
			unset db_dest_path db_dest_path_pkg db_repo_name db_old_cid

		else
			echo "Warning: Couldn't process deleted file '$deleted_file', unknown file type"  >&2
		fi
	done < <(grep ' *deleting' "${rsync_log}" | awk '{ print $5 }' | grep -v '^lastupdate$')

	#changed files
	while IFS= read -r -d $'\n' changed_file; do
		if [[ $changed_file = *'.pkg.'* ]]; then #that's a pkg
			echo "Warning: the pkg file '$changed_file' was changed on mirror, this is unexpected!" >&2
			pkg_name=$(echo "$changed_file" | cut -d'/' -f4)
			pkg_repo_folder=$(echo "$changed_file" | cut -d'/' -f1)
			pkg_folder_path="$ipfs_repo_folder/$pkg_repo_folder"
			if ! ipfs files stat "/$pkg_folder_path" > /dev/null 2>&1; then
				echo "Warning: Changed file's ($changed_file) folder wasn't existing, creating a new folder" >&2
				ipfs files mkdir -p --cid-version 1 "/$pkg_folder_path" > /dev/null 2>&1 || fail "ipfs folder for pkg could not be created: /$pkg_folder_path" 1002 -n
			fi

			if ! pkg_cid=$(add_file_to_cluster 'pkg' "$pkg_repo_folder" "$pkg_name"); then
				echo "Warning: rsync log inconsistent! changed file '$changed_file' could not be located, skipping" >&2
				continue
			fi
			pkg_dest_path="/$pkg_folder_path/$pkg_name"
			pkg_pacmanstore_dest_path="/$ipfs_pkg_cache_folder/$pkg_name"
			if ! pkg_old_cid=$(ipfs files stat --hash "$pkg_dest_path"); then
				echo "Warning: ifps inconsistent! changed file '$changed_file' could not be located, adding as a new file" >&2
			else #add expire date to old pin
				if [ "$pkg_cid" == "$pkg_old_cid" ]; then
					echo "Warning: changed file got the same content as the old one. Old CID: '$pkg_old_cid' path: '$pkg_dest_path'. SKIPPING EXPIRING PIN" >&2
				else
					add_expiredate_to_clusterpin "$pkg_old_cid" 'pkg' "$pkg_repo_folder" "$pkg_name"
				fi
				ipfs files rm "$pkg_dest_path"
			fi
			ipfs files cp "/ipfs/$pkg_cid" "$pkg_dest_path" > /dev/null 2>&1
			ipfs files rm "$pkg_pacmanstore_dest_path" > /dev/null 2>&1 || echo "Warning: Changed pkg $pkg_name haven't existed in pkg cache folder, ADDING"  >&2
			ipfs files cp "/ipfs/$pkg_cid" "$pkg_pacmanstore_dest_path" > /dev/null 2>&1
			unset pkg_name pkg_repo_folder pkg_folder_path pkg_cid pkg_dest_path pkg_pacmanstore_dest_path

		elif [ "${changed_file:0:4}" == 'iso/' ]; then #that's everything in iso/
			echo "Warning: the file in /iso '$changed_file' was changed on mirror, this is unexpected!" >&2
			iso_file_name=$(echo "$changed_file" | cut -d'/' -f3)
			iso_file_folder=$(echo "$changed_file" | cut -d'/' -f2)
			iso_dest_path="/$ipfs_iso_folder/$distarchrepo_path/$iso_file_folder/$iso_file_name"
			if ! iso_cid=$(add_file_to_cluster 'iso' "$iso_file_folder" "$iso_file_name"); then
				echo "Warning: rsync log inconsistent! changed file '$changed_file' could not be located, skipping" >&2
				continue
			fi
			if ! iso_old_cid=$(ipfs files stat --hash "$iso_dest_path"); then
				echo "Warning: ifps inconsistent! changed file '$changed_file' could not be located, adding as a new file" >&2
			else
				if [ "$iso_cid" == "$iso_old_cid" ]; then
					echo "Warning: changed file got the same content as the old one. Old CID: '$iso_old_cid' path: '$iso_dest_path'. SKIPPING" >&2
					continue
				fi
				add_expiredate_to_clusterpin "$iso_old_cid" 'iso' "$iso_file_folder" "$iso_file_name"
				ipfs files rm "$iso_dest_path"
			fi
			ipfs files cp "/ipfs/$iso_cid" "$iso_dest_path"
			unset iso_file_name iso_file_folder iso_dest_path iso_old_cid iso_cid

		elif [ "${changed_file: -3}" == '.db' ]; then # that's a database file
			db_repo_name=$(echo "$changed_file" | cut -d'/' -f1)
			db_dest_path="/$ipfs_db_folder/${db_repo_name}.db"
			db_dest_path_pkg="/$ipfs_repo_folder/$db_repo_name/${db_repo_name}.db"
			if ! db_cid=$(add_file_to_cluster 'db' "$db_repo_name"); then
				echo "Warning: rsync log inconsistent! changed file '$changed_file' could not be located, skipping" >&2
				continue
			fi
			if ! db_old_cid=$(ipfs files stat --hash "$db_dest_path"); then
				echo "Warning: ifps inconsistent! changed file '$changed_file' could not be located, adding as a new file" >&2
			else
				if [ "$db_cid" == "$db_old_cid" ]; then
					echo "Warning: changed file got the same content as the old one. Old CID: '$db_old_cid' path: '$db_dest_path'. SKIPPING" >&2
					# ensure copy in repo folder is the same
					db_old_cid_pkg=$(ipfs files stat --hash "$db_dest_path_pkg") || true
					if [ "$db_old_cid" != "$db_old_cid_pkg" ]; then
						ipfs files rm "$db_dest_path_pkg" || true
						ipfs files cp "$db_dest_path" "$db_dest_path_pkg" || true
					fi
					continue
				fi
				add_expiredate_to_clusterpin "$db_old_cid" 'db' "$db_repo_name"
				ipfs files rm "$db_dest_path"
				ipfs files rm "$db_dest_path_pkg" || true
			fi
			ipfs files cp "/ipfs/$db_cid" "$db_dest_path"
			db_pkg_folder_path="/$ipfs_repo_folder/$db_repo_name"
			if ! ipfs files stat "/$db_pkg_folder_path" > /dev/null 2>&1; then
				echo "Warning: Changed db file's ($changed_file) repo folder wasn't existing, creating a new folder" >&2
				ipfs files mkdir -p --cid-version 1 "/$db_pkg_folder_path" > /dev/null 2>&1 || fail "ipfs folder for pkg could not be created: /$db_pkg_folder_path" 1000 -n
			fi
			ipfs files cp "/ipfs/$db_cid" "$db_dest_path_pkg"
			unset db_repo_name db_dest_path db_dest_path_pkg db_old_cid db_old_cid_pkg db_cid db_pkg_folder_path

		else
			echo "Warning: Couldn't process changed file '$changed_file', unknown file type"  >&2
		fi
	done < <(grep -v ' >f+++++++++' "${rsync_log}" | grep ' >f' | awk '{ print $5 }' | grep -v '^lastupdate$')

	#new files
	while IFS= read -r -d $'\n' new_file; do
		if [[ $new_file = *'.pkg.'* ]]; then #that's a pkg
			pkg_name=$(echo "$new_file" | cut -d'/' -f4)
			pkg_repo_folder=$(echo "$new_file" | cut -d'/' -f1)
			pkg_folder_path="$ipfs_repo_folder/$pkg_repo_folder"
			if ! ipfs files stat "/$pkg_folder_path" > /dev/null 2>&1; then
				ipfs files mkdir -p --cid-version 1 "/$pkg_folder_path" > /dev/null 2>&1 || fail "ipfs folder for pkg could not be created: /$pkg_folder_path" 1000 -n
			fi
			if ! pkg_cid=$(add_file_to_cluster 'pkg' "$pkg_repo_folder" "$pkg_name"); then
				echo "Warning: rsync log inconsistent! new file '$new_file' could not be located, skipping" >&2
				continue
			fi
			pkg_dest_path="/$pkg_folder_path/$pkg_name"
			pkg_pacmanstore_dest_path="/$ipfs_pkg_cache_folder/$pkg_name"
			if [ "$RECOVER" -eq 1 ]; then
				ipfs files rm "$pkg_dest_path" > /dev/null 2>&1 || true # ignore if the file doesn't exist
			fi
			ipfs files cp "/ipfs/$pkg_cid" "$pkg_dest_path" > /dev/null 2>&1 || echo "Warning: New pkg file $pkg_name already existed on IPFS"  >&2
			if ipfs files rm "$pkg_pacmanstore_dest_path" > /dev/null 2>&1; then
				echo "Warning: New pkg file $pkg_name already existed in pkg cache folder, replacing with new version"  >&2
			fi
			ipfs files cp "/ipfs/$pkg_cid" "$pkg_pacmanstore_dest_path" > /dev/null 2>&1
			unset pkg_name pkg_repo_folder pkg_folder_path pkg_cid pkg_dest_path pkg_pacmanstore_dest_path

		elif [ "${new_file:0:4}" == 'iso/' ]; then #that's everything in iso/
			iso_file_name=$(echo "$new_file" | cut -d'/' -f3)
			iso_file_folder=$(echo "$new_file" | cut -d'/' -f2)
			iso_folder_path="$ipfs_iso_folder/$distarchrepo_path/$iso_file_folder"
			if ! ipfs files stat "/$iso_folder_path" > /dev/null 2>&1; then
				ipfs files mkdir -p --cid-version 1 "/$iso_folder_path" > /dev/null 2>&1 || fail "ipfs folder for iso files could not be created: /$iso_folder_path" 1001 -n
			fi
			if ! iso_cid=$(add_file_to_cluster 'iso' "$iso_file_folder" "$iso_file_name"); then
				echo "Warning: rsync log inconsistent! new file '$new_file' could not be located, skipping" >&2
				continue
			fi
			iso_dest_path="/$iso_folder_path/$iso_file_name"
			if [ "$RECOVER" -eq 1 ]; then
				ipfs files rm "$iso_dest_path" > /dev/null 2>&1 || true # ignore if the file doesn't exist
			fi
			ipfs files cp "/ipfs/$iso_cid" "$iso_dest_path" > /dev/null 2>&1 || echo "Warning: New iso file $iso_file_name already existed on IPFS"  >&2
			unset iso_file_name iso_file_folder iso_folder_path iso_cid iso_dest_path

		elif [ "${new_file: -3}" == '.db' ]; then # that's a database file
			db_repo_name=$(echo "$new_file" | cut -d'/' -f1)
			if ! db_cid=$(add_file_to_cluster 'db' "$db_repo_name"); then
				echo "Warning: rsync log inconsistent! new file '$new_file' could not be located, skipping" >&2
				continue
			fi
			db_dest_path="/$ipfs_db_folder/${db_repo_name}.db"
			db_dest_path_pkg="/$ipfs_repo_folder/$db_repo_name/${db_repo_name}.db"
			if [ "$RECOVER" -eq 1 ]; then
				ipfs files rm "$db_dest_path" > /dev/null 2>&1 || true # ignore if the file doesn't exist
				ipfs files rm "$db_dest_path_pkg" > /dev/null 2>&1 || true # ignore if the file doesn't exist
			fi
			ipfs files cp "/ipfs/$db_cid" "$db_dest_path" > /dev/null 2>&1 || echo "Warning: New db file $db_repo_name already existed on IPFS"  >&2
			db_pkg_folder_path="/$ipfs_repo_folder/$db_repo_name"
			if ! ipfs files stat "/$db_pkg_folder_path" > /dev/null 2>&1; then
				ipfs files mkdir -p --cid-version 1 "/$db_pkg_folder_path" > /dev/null 2>&1 || fail "ipfs folder for pkg could not be created: /$db_pkg_folder_path" 1000 -n
			fi
			ipfs files cp "/ipfs/$db_cid" "$db_dest_path_pkg" > /dev/null 2>&1 || echo "Warning: New db file $db_repo_name already existed on IPFS in repo folder"  >&2
			unset db_repo_name db_cid db_dest_path db_dest_path_pkg pkg_folder_path

		else
			echo "Warning: Couldn't process new file '$new_file', unknown file type"  >&2

		fi
	done < <(grep ' >f+++++++++' "${rsync_log}" | awk '{ print $5 }' | grep -v '^lastupdate$')

else # FULL_ADD is set - full add mechanism
	cd "$rsync_target"

	no_of_adds=1

	while IFS= read -r -d $'\0' filename; do
		if [[ $filename = *"/~"* ]]; then
			echo "Warning: Skipped file with '/~' in path: $filename"  >&2
			continue
		elif [[ $filename = *"/."* ]]; then
			echo "Warning: Skipped hidden file/folder: $filename"  >&2
			continue
		elif [ "$filename" == "./lastupdate" ]; then
			continue
			#lastupdate_folder_path="$ipfs_repo_folder"
			#lastupdate_timestamp=$(date --utc -Iseconds)
			#lastupdate_cid=$(add_file_to_cluster 'note' "${rsync_target}/lastupdate" "$lastupdate_folder_path/lastupdate-$lastupdate_timestamp")
			#lastupdate_dest_path="/$lastupdate_folder_path/lastupdate"
			#ipfs files rm "$lastupdate_dest_path" > /dev/null 2>&1 || true # ignore if the file doesn't exist
			#ipfs files cp "/ipfs/$lastupdate_cid" "$lastupdate_dest_path"
			#unset lastupdate_folder_path lastupdate_timestamp lastupdate_cid lastupdate_dest_path
		fi
		if [[ $filename = *'.pkg.'* ]]; then #that's a pkg
			pkg_name=$(echo "$filename" | cut -d'/' -f5)
			pkg_repo_folder=$(echo "$filename" | cut -d'/' -f2)
			pkg_folder_path="$ipfs_repo_folder/$pkg_repo_folder"
			pkg_cid=$(add_file_to_cluster 'pkg' "$pkg_repo_folder" "$pkg_name")
			if ! ipfs files stat "/$pkg_folder_path" > /dev/null 2>&1; then
				ipfs files mkdir -p --cid-version 1 "/$pkg_folder_path" > /dev/null 2>&1 || fail "ipfs folder for pkg could not be created: /$pkg_folder_path" 2000 -n
			fi
			pkg_dest_path="/$pkg_folder_path/$pkg_name"
			pkg_pacmanstore_dest_path="/$ipfs_pkg_cache_folder/$pkg_name"
			ipfs files cp "/ipfs/$pkg_cid" "$pkg_dest_path" > /dev/null 2>&1
			if ! ipfs files cp "/ipfs/$pkg_cid" "$pkg_pacmanstore_dest_path" > /dev/null 2>&1; then
				pkg_old_cache_cid=$(ipfs files stat --hash "$pkg_pacmanstore_dest_path")
				if [ "$pkg_cid" == "$pkg_old_cache_cid" ]; then
					echo "Warning: new pkg file $pkg_name already existed in pkg cache folder, but CID match, IGNORING" >&2
				else
					echo "Warning: Conflicting package name, pkg file $pkg_name already existed in pkg cache folder and CID missmatch - deleting cache entry" >&2
					ipfs files rm "$pkg_pacmanstore_dest_path"
				fi
			fi
			unset pkg_name pkg_repo_folder pkg_folder_path pkg_cid pkg_dest_path pkg_pacmanstore_dest_path pkg_old_cache_cid

		elif [ "${filename:0:6}" == './iso/' ]; then #that's everything in iso/
			iso_file_name=$(echo "$filename" | cut -d'/' -f4)
			iso_file_folder=$(echo "$filename" | cut -d'/' -f3)
			iso_cid=$(add_file_to_cluster 'iso' "$iso_file_folder" "$iso_file_name")
			iso_folder_path="$ipfs_iso_folder/$distarchrepo_path/$iso_file_folder"
			if ! ipfs files stat "/$iso_folder_path" > /dev/null 2>&1; then
				ipfs files mkdir -p --cid-version 1 "/$iso_folder_path" > /dev/null 2>&1
			fi
			iso_dest_path="/$iso_folder_path/$iso_file_name"
			ipfs files cp "/ipfs/$iso_cid" "$iso_dest_path"
			unset iso_file_name iso_file_folder iso_cid iso_folder_path iso_dest_path

		elif [ "${filename: -3}" == '.db' ]; then #that's a database file
			db_repo_name=$(echo "$filename" | cut -d'/' -f2)
			db_cid=$(add_file_to_cluster 'db' "$db_repo_name")
			db_dest_path="/$ipfs_db_folder/${db_repo_name}.db"
			db_dest_path_pkg="/$ipfs_repo_folder/$db_repo_name/${db_repo_name}.db"
			ipfs files cp "/ipfs/$db_cid" "$db_dest_path"
			db_pkg_folder_path="/$ipfs_repo_folder/$db_repo_name"
			if ! ipfs files stat "/$db_pkg_folder_path" > /dev/null 2>&1; then
				ipfs files mkdir -p --cid-version 1 "/$db_pkg_folder_path" > /dev/null 2>&1 || fail "ipfs folder for pkg could not be created: /$db_pkg_folder_path" 2000 -n
			fi
			ipfs files cp "/ipfs/$db_cid" "$db_dest_path_pkg"
			unset db_repo_name db_cid db_dest_path db_dest_path_pkg

		else
			echo "Warning: Couldn't process file '$filename', unknown file type"  >&2
		fi
		(( no_of_adds % 100 )) || echo "$no_of_adds files processed..."
		(( no_of_adds++ ))
	done < <(find . -type f -print0)
fi

timestamp="$(date --utc -Iseconds)"

printf "\n:: sync completed, start archiving and publishing @ %s\n" "$timestamp"


#get new rootfolder CIDs
ipfs_pkg_folder_cid=$(ipfs files stat --hash "/$ipfs_pkg_folder") || fail 'repo folder (IPFS) CID could not be determined after update is completed' 400
ipfs_iso_folder_cid=$(ipfs files stat --hash "/$ipfs_iso_folder")  || fail 'iso folder (IPFS) CID could not be determined after update is completed' 402

# Pin all folders recursive on the cluster for $cluster_pin_rootfolder_expire (for distributed lookup of folders, while independent of the file-lifetime in the cluster)
#pin_rootfolder_to_cluster "$ipfs_pkg_folder_cid" "$ipfs_pkg_folder" "$timestamp"
#pin_rootfolder_to_cluster "$ipfs_iso_folder_cid" "$ipfs_iso_folder" "$timestamp"

echo -ne "start publishing new ipns..."
# publish new ipns records
ipfs name publish --timeout 3m --resolve=false --allow-offline --ttl '1m' --lifetime '96h' --key="$ipfs_pkg_folder" "/ipfs/$ipfs_pkg_folder_cid" > /dev/null || printf '\nWarning: Repo folder (IPFS) IPNS could not be published after update\n' >&2
ipfs name publish --timeout 3m --resolve=false --allow-offline --ttl '1m' --lifetime '96h' --key="$ipfs_iso_folder" "/ipfs/$ipfs_iso_folder_cid" > /dev/null || printf '\nWarning: ISO folder (IPFS) IPNS could not be published after update\n' >&2
ipfs name publish --timeout 3m --resolve=false --allow-offline --ttl '2h' --lifetime '96h' --key="cluster.pacman.store" "/ipfs/bafkreih2ee52pz5ruxzfi4kofe6i3wnbhmn3sscghrwfeejdkov4f6rpz4" > /dev/null || printf '\nWarning: ISO folder (IPFS) IPNS could not be published after update\n' >&2

printf '\n:: operation successfully completed @ %s\n' "$(date -Iseconds)"

if [ $FULL_ADD -eq 0 ]; then
	cat "$rsync_log" >> "$rsync_log_archive"
	rm -f "$rsync_log"
fi
