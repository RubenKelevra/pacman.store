#!/bin/bash
# shellcheck disable=SC2015

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

# simple script to convert and update an rsync'ed folder
# to an ipfs-mfs with ipfs-cluster pinning

# dependencies:
# - `dos2unix`
# - `date`
# - `ipfs-cluster-ctl`
# - `ipfs`
# - a running ipfs-cluster-service
# - a running ipfs
# - twice the storage of the rsynced folder
# - ipfs fuse-mount function not in use
# - depending on the size of the directories, the IPFS-option for directory sharding might need to be active

# limitations:
# - might not properly delete folders from MFS
# - ignores paths (in rsync folder) starting with a dot (not synced with MFS)
# - ignores files/folders starting with a dot (not synched with MFS)
# - can't process paths (in rsync folder) with a space (will break sync completly)
# - path/filename cannot contain 'WARNING:'
# - won't handle empty folders properly

# available arguments:
# --create - use this flag on the first run

# check environment

[ -z "${HOME}" ] && fail "the system variable \$HOME was empty" 26

# ipfs-mfs folder
ipfs_folder='x86-64.archlinux.pkg.pacman.store'

# key name and settings for publishing the ipns
ipfs_ipns_name="$ipfs_folder"
ipfs_ipns_ttl='5m'
ipfs_ipns_lifetime='96h'
ipfs_chunker='buzhash'
ipfs_hash='blake2b-256'
ipfs_cid='1'

ipfs_api_host="/ip4/127.0.0.1/tcp/5001"
cluster_api_host="/ip4/127.0.0.1/tcp/9094"

# set both -1 for 'everywhere', set 0 for 'default settings of the cluster'
default_cluster_replication_min="-1"
default_cluster_replication_max="-1"

#default_cluster_pin_expire="30d"
default_cluster_pin_expire="2592000s" #workaround for broken parsing in 0.13

# directory where rsync should target (needs to end with a slash)
rsync_target="${HOME}/$ipfs_folder/"

# rsync url
rsync_source='rsync://mirror.f4st.host/archlinux/'

# http/https url to the lastupdate file on the same server, to skip unnecessary rsync syncs
lastupdate_url='https://mirror.f4st.host/archlinux/lastupdate'

# Lockfile path
lock="${HOME}/.rsync2cluster/$ipfs_folder.lock"

# current logfile path
rsync_log="${HOME}/.rsync2cluster/$ipfs_folder.log"

# rsync log archive
rsync_log_archive="${HOME}/.rsync2cluster/${ipfs_folder}_archive.log"

#### END CONFIG

# local functions

function fail() {
	[ -n "$3" ] && [ "$3" == '-n' ] && printf '\n'
	[ -n "$3" ] && [ "$3" == '-2n' ] && printf '\n\n'
	printf 'Error: %s; Errorcode: %s\n' "$1" "$2" >&2
	exit 1
}

function warn() {
	[ -n "$2" ] && [ "$2" == '-n' ] && printf '\n'
	[ -n "$2" ] && [ "$2" == '-2n' ] && printf '\n\n'
	printf 'Warning: %s\n' "$1" >&2
}

function get_timestamp() {
	date --utc -Iseconds
}

function get_frozen_name() {
	local _name="$1"
	
	echo "${_name}@$(get_timestamp)"
}

function rsync_main_cmd() {
	local log_file_folder=""
	
	log_file_folder=$(get_path_wo_fn "$rsync_log")
	[ ! -d "$log_file_folder" ] && fail "the log folder for rsync couldn't not be located" 1950
	[ -f "$rsync_log" ] && fail "the rsync log file does already exist" 1951
	touch "$rsync_log" || fail "no file create-access for rsync log file" 1952
	echo "0" > "$rsync_log"  || fail "no file write-access for rsync log file" 1952
	rm "$rsync_log" || fail "no delete-access for rsync log file" 1953
	
	local -a cmd=(rsync -rtlH -LK --safe-links --delete-excluded --delete --delete-during --inplace "--log-file=$rsync_log" "--timeout=600" "--contimeout=60" -p --no-motd --quiet)
	
	"${cmd[@]}" "$@"
}

function ipfs_api() {
	local -a cmd=(ipfs --api="$ipfs_api_host")
	
	"${cmd[@]}" "$@"
	return $?
}

function ipfs-cluster-ctl_api() {
	local -a cmd=(ipfs-cluster-ctl --host "$cluster_api_host")
	
	"${cmd[@]}" "$@"
	return $?
}

### Not used; not maintained

# function rm_clusterpin() {
# 	local _cid="$1"
#
# 	if ! ipfs-cluster-ctl_api pin rm --no-status "$_cid" > /dev/null; then
# 		fail "ipfs-cluster-ctl returned an error while removing a cluster pin: cid: '$_cid'" 237
# 	fi
# }

# function update_clusterpin() {
# 	local _old_cid="$1"
# 	local _new_cid="$2"
#
# 	if ! ipfs-cluster-ctl_api pin update --no-status "$_old_cid" "$_new_cid" > /dev/null; then
# 		fail "ipfs-cluster-ctl returned an error while updating a cluster pin:\n     old cid: '$_old_cid', new cid: '$_new_cid'" 238
# 	elif ! ipfs-cluster-ctl_api pin rm --no-status "$_old_cid" > /dev/null; then
# 		fail "ipfs-cluster-ctl returned an error while removing old cluster pin after updating:\n     old cid: '$_old_cid', new cid: '$_new_cid'" 239
# 	fi
# }

### END not used; not maintained

function add_direct_clusterpin() {
	local _cid="$1"
	# can be empty
	local _name="$2"
	# if set the pins will be removed from the cluster after this time automatically (set to 'default' if you want the global defaults)
	local _timeout="$3"
	# use for overwriting the default settings in the config of this script
	local _replication_min="$4"
	local _replication_max="$5"
	
	add_clusterpin "$_cid" "$_name" "$_timeout" "$_replication_min" "$_replication_max" "direct"
}

function add_clusterpin() {
	local _cid="$1"
	# can be empty
	local _name="$2"
	# if set the pins will be removed from the cluster after this time automatically (set to 'default' if you want the global defaults)
	local _timeout="$3"
	# use for overwriting the default settings in the config of this script
	local _replication_min="$4"
	local _replication_max="$5"
	# use add_direct_clusterpin() if you want a shorter call
	local _mode="$6"
	
	# load global defaults if nothing is set
	[ -z "$_replication_min" ] && _replication_min="$default_cluster_replication_min"
	[ -z "$_replication_max" ] && _replication_max="$default_cluster_replication_max"
	
	# load global default if 'default' is set, otherwise the pin doesn't expire
	[ "$_timeout" == "default" ] && _timeout="$default_cluster_pin_expire"
	
	# set default
	[ -z "$_mode" ] && _mode="recursive"
	
	# error handling
	[ -z "$_cid" ] && fail "add_clusterpin() was called with an empty cid" 244
	[ "$_mode" != "recursive" ] && [ "$_mode" != "direct" ] && fail "add_clusterpin() was called with a unexpected pinning mode '$_mode'"
	
	if [ -n "$_timeout" ]; then
		if ! ipfs-cluster-ctl_api pin add --no-status --name "$_name" --expire-in "$_timeout" --mode "$_mode" --replication-min="$_replication_min" --replication-max="$_replication_max" "$_cid" >/dev/null 2>&1; then
			fail "ipfs-cluster-ctl returned an error while pinning cid '$_cid', name: '$_name'" 201
		fi
		return
	fi
	if ! ipfs-cluster-ctl_api pin add --no-status --name "$_name" --mode "$_mode" --replication-min="$_replication_min" --replication-max="$_replication_max" "$_cid" >/dev/null 2>&1; then
		fail "ipfs-cluster-ctl returned an error while pinning cid '$_cid', name: '$_name'" 201
	fi
}

function rewrite_log_path() {
	[ -z "$1" ] && fail "rewrite_log_path() was called with an empty argument" 274
	#search and replace
	output=$(echo "$1" | sed 's/\/os\/x86_64\//\//')
	
	#echo return string
	echo "$output"
}

function ipfs_mfs_path_exist() {
	[ -z "$1" ] && fail "ipfs_mfs_path_exist() was called with an empty argument" 275
	ipfs_api files stat --hash "$1" >/dev/null 2>&1
	return $?
}

function ipfs_mfs_file_rm() {
	[ -z "$1" ] && fail "ipfs_mfs_file_rm() was called with an empty argument" 276
	ipfs_api files rm "$1" >/dev/null 2>&1
	return $?
}

function get_path_wo_fn() {
	[ -z "$1" ] && fail "get_path_wo_fn() was called with an empty argument" 277
	echo "$1" | rev | cut -d"/" -f2-  | rev
}

function ipfs_mfs_mkdir_path() {
	[ -z "$1" ] && fail "ipfs_mfs_mkdir_path() was called with an empty argument" 278
	ipfs_api files mkdir -p --cid-version 1 "$1" >/dev/null 2>&1
	return $?
}

function ipfs_mfs_mkdir() {
	[ -z "$1" ] && fail "ipfs_mfs_mkdir() was called with an empty argument" 279
	ipfs_api files mkdir --cid-version 1 "$1" >/dev/null 2>&1
	return $?
}

function ipfs_mfs_add_file() {
	# expect a filepath
	[ -z "$1" ] && fail "ipfs_mfs_add_file() was called with an empty first argument" 280
	# expect a mfs destination path
	[ -z "$2" ] && fail "ipfs_mfs_add_file() was called with an empty second argument" 281
	[ ! -f "$1" ] && fail "ipfs_mfs_add_file() was called with a path to a file which didn't exist: '$1'" 282
	local _cid=""
	
	if ! _cid=$(ipfs_api add --chunker "$ipfs_chunker" --hash "$ipfs_hash" --cid-version "$ipfs_cid" --quieter "$1"); then
		fail "ipfs_mfs_add_file() could not add the file '$1' to ipfs" 283
	elif ! ipfs_api files cp "/ipfs/$_cid" "$2" >/dev/null 2>&1; then
		fail "ipfs_mfs_add_file() could not copy the file '$1' to the mfs location '$2'. CID: '$_cid'" 284
	elif ! ipfs_api pin rm "/ipfs/$_cid" >/dev/null 2>&1; then
		fail "ipfs_mfs_add_file() could not unpin the temporarily pinned file '$1'. CID: '$_cid'" 285
	fi
	
}

function create_lock_path() {
	local lock_path=""
	lock_path=$(get_path_wo_fn "${lock}")
	mkdir -p "$lock_path" || fail "could not create folder for lock file" 1044
}

function create_log_path() {
	local log_path=""
	log_path=$(get_path_wo_fn "${rsync_log}")
	mkdir -p "$log_path" || fail "could not create folder for lock file" 1044
}

function create_log_archive_path() {
	local log_archive_path=""
	log_archive_path=$(get_path_wo_fn "${rsync_log_archive}")
	mkdir -p "$log_archive_path" || fail "could not create folder for lock file" 1044
}

#create folders for log and lock if they don't exist
create_lock_path
create_log_path
create_log_archive_path

# get lock or exit
exec 9> "${lock}"
flock -n 9 || exit

# state variables
CREATE=0
RECOVER=0
NOIPNS=0
NOCLUSTER=0

# argument definition
cmd_flags=(
   "create"
   "no-ipns"
   "no-cluster"
)

#help message
usage() {
	echo "Usage: $0$(printf " [--%s]" "${cmd_flags[@]}")" 1>&2
	exit 1
}

# argument decoding
if ! opts=$(getopt \
   --longoptions "$(printf "%s," "${cmd_flags[@]}")" \
   --name "$(basename "$0")" \
   --options "" \
   -- "$@"
); then
	usage
fi

eval set --$opts

while true; do
	case "$1" in
		--create)
			echo "import local directory..."
			CREATE=1
			;;
		--no-ipns)
			NOIPNS=1
			;;
		--no-cluster)
			NOCLUSTER=1
			;;
		--)
			shift
			break
			;;
	esac
	shift
done

# check config

nul_str='config string is empty'

[ -z "$rsync_target" ] && fail "rsync target dir $nul_str" 10
[ -z "$lock" ] && fail "lock file $nul_str" 12
[ -z "$rsync_log" ] && fail "rsync log-file $nul_str" 13
[ -z "$rsync_log_archive" ] && fail "rsync log archive file $nul_str" 14
[ -z "$rsync_source" ] && fail "rsync source url $nul_str" 16
[ -z "$lastupdate_url" ] && fail "lastupdate url $nul_str" 17
[ -z "$ipfs_folder" ] && fail "ipfs mfs folder $nul_str" 18
if [ "$NOIPNS" -eq 0 ]; then
	[ -z "$ipfs_ipns_name" ] && fail "ipfs ipns name $nul_str" 19
	[ -z "$ipfs_ipns_ttl" ] && fail "ipfs ipns ttl $nul_str" 20
	[ -z "$ipfs_ipns_lifetime" ] && fail "ipfs ipns lifetime $nul_str" 21
fi
if [ "$NOCLUSTER" -eq 0 ]; then
	[ -z "$default_cluster_replication_min" ] && fail "ipfs-cluster minimal replication $nul_str" 22
	[ -z "$default_cluster_replication_max" ] && fail "ipfs-cluster maximal replication $nul_str" 23
	[ -z "$default_cluster_pin_expire" ] && fail "ipfs-cluster pin expire $nul_str" 24
	[ -z "$cluster_api_host" ] && fail "ipfs-cluster api-host $nul_str" 25
fi
[ -z "$ipfs_api_host" ] && fail "ipfs api-host $nul_str" 27
[ -z "$ipfs_chunker" ] && fail "ipfs chunker $nul_str" 28
[ -z "$ipfs_hash" ] && fail "ipfs hash algorithm $nul_str" 29
[ -z "$ipfs_cid" ] && fail "ipfs cid $nul_str" 30

# check/create directories
if [ ! -d "${rsync_target}" ]; then
	mkdir -p "${rsync_target}" || fail "creation of rsync target directory failed" 39
fi

#check mfs

if [ $CREATE -eq 1 ]; then
	echo -ne "creating empty ipfs folder in mfs..."
	if ! ipfs_mfs_path_exist "/$ipfs_folder"; then
		ipfs_mfs_mkdir "/$ipfs_folder" || fail "ipfs folder couldn't be created in mfs" 100 -n
	else
		fail "ipfs folder did already exist" 101 -n
	fi
elif ! ipfs_api files stat "/$ipfs_folder" > /dev/null 2>&1; then
	fail "configured ipfs folder does not exist in mfs, to import existing folder use '--create' flag" 300 -n
fi
echo "done"

# print a warning if the previous process haven't deleted the log of rsync
# we will read and reapply the previous rsync log
if [ $CREATE -eq 0 ]; then
	if [ -f "$rsync_log" ]; then
		warn "Last sync with ipfs was incomplete, reread the last transmission log"
		RECOVER=1
	fi
else
	RECOVER=0
fi

# don't run rsync on directory when recovering
if [ "$RECOVER" -eq 0 ]; then
	
	# force update if we're creating
	[ "$CREATE" -eq 1 ] && rm -f "${rsync_target}lastupdate" || true
	
	# only run when there are changes
	if [[ -f "${rsync_target}lastupdate" ]] && diff -b <(curl -Ls "$lastupdate_url") "${rsync_target}lastupdate" > /dev/null; then
		# exit here if we should do a delta update but there's nothing to do
		[ "$CREATE" -eq 0 ] && exit 0
	fi
	
	printf '\n:: starting rsync operation @ %s\n' "$(get_timestamp)"
	
	if [ "$NOCLUSTER" -eq 0 ]; then
		#use timestamp of the rsync call as "frozen name"
		cluster_pin_frozen_name=$(get_frozen_name "$ipfs_folder")
	fi
	
	rsync_main_cmd --exclude='/pool' "${rsync_source}" "${rsync_target}"
fi

if [ $CREATE -eq 0 ]; then
	#fix broken rsync logs
	dos2unix -q -c mac "$rsync_log"
	sync
else #delete rsync log and archive (if existing)
	rm -f "$rsync_log" || true
	rm -f "$rsync_log_archive" || true
	sync
fi

if [ $CREATE -eq 0 ]; then #diff update mechanism
	printf '\n:: start parsing rsync log @ %s\n' "$(get_timestamp)"
	
	[ ! -f "${rsync_log}" ] && fail "could not locate rsync log" 1999

	#deleted files
	while IFS= read -r -d $'\n' log_path; do
		deleted_filepath=$(rewrite_log_path "$log_path")
		mfs_filepath="/$ipfs_folder/$deleted_filepath"
		if ! ipfs_mfs_path_exist "$mfs_filepath"; then
			warn "the file '$deleted_filepath' was already deleted on IPFS"
			continue
		fi
		
		if ! ipfs_mfs_file_rm "$mfs_filepath"; then
			fail "the file '$deleted_filepath' exists but couldn't be removed" 292
		fi
		unset deleted_filepath mfs_filepath
	done < <(grep ' *deleting' "${rsync_log}" | awk '{ print $5 }' | grep -v '/$' | grep -v '^\.' | grep -v '/\.')
	
	unset log_path

	#changed files
	while IFS= read -r -d $'\n' log_path; do
		changed_filepath=$(rewrite_log_path "$log_path")
		mfs_filepath="/$ipfs_folder/$changed_filepath"
		mfs_parent_folder=$(get_path_wo_fn "$mfs_filepath")
		fs_filepath="${rsync_target}$log_path"
		
		if ! ipfs_mfs_path_exist "$mfs_filepath"; then
			warn "the changed file '$changed_filepath' was deleted on IPFS, readding"
			# ensure the directory (path) exists
			if ! ipfs_mfs_path_exist "$mfs_parent_folder"; then
				warn "the changed file '$changed_filepath's folder wasn't existing, creating"
				if ! ipfs_mfs_mkdir_path "$mfs_parent_folder"; then
					fail "the changed file '$changed_filepath's folder couldn't be created" 288
				fi
			fi
		else
			if ! ipfs_mfs_file_rm "$mfs_filepath"; then
				fail "the changed file '$changed_filepath' exists but couldn't be removed" 291
			fi
		fi
		
		ipfs_mfs_add_file "$fs_filepath" "$mfs_filepath"
		
		unset changed_filepath mfs_filepath mfs_parent_folder fs_filepath
	done < <(grep -v ' >f+++++++++' "${rsync_log}" | grep ' >f' | awk '{ print $5 }' | grep -v '/$' | grep -v '^\.' | grep -v '/\.')
	
	unset log_path

	#new files
	while IFS= read -r -d $'\n' log_path; do
		new_filepath=$(rewrite_log_path "$log_path")
		mfs_filepath="/$ipfs_folder/$new_filepath"
		mfs_parent_folder=$(get_path_wo_fn "$mfs_filepath")
		fs_filepath="${rsync_target}$log_path"
		
		if ipfs_mfs_path_exist "$mfs_filepath"; then
			warn "the new file '$new_filepath' was already existing on IPFS, deleting"
			if ! ipfs_mfs_file_rm "$mfs_filepath"; then
				fail "the file '$new_filepath' exists but couldn't be removed from IPFS" 290
			fi
		else
			# ensure the directory (path) exists
			if ! ipfs_mfs_path_exist "$mfs_parent_folder"; then
				if ! ipfs_mfs_mkdir_path "$mfs_parent_folder"; then
					fail "the new file '$new_filepath's folder couldn't be created" 289
				fi
			fi
		fi
		
		ipfs_mfs_add_file "$fs_filepath" "$mfs_filepath"
		
		unset new_filepath mfs_filepath mfs_parent_folder fs_filepath
	done < <(grep ' >f+++++++++' "${rsync_log}" | awk '{ print $5 }' | grep -v '/$' | grep -v '^\.' | grep -v '/\.')

	unset log_path
	
	print_warning=1

	while IFS= read -r -d $'\n' log_path; do
		if [ "$print_warning" -eq 1 ]; then
			print_warning=0
			warn "rsync printed a warning, forced resync on the next run"
			
			if [ ! -z "${rsync_target}" ]; then
				if ! rm "${rsync_target}lastupdate"; then
					fail "there was a warning in the rsync log, but the lastupdate file couldn't be deleted" 488
				fi
			else
				fail "rsync target variable was unexpectedly empty" 489
			fi
		fi
	done < <(grep 'WARNING:' "${rsync_log}")
	
	unset print_warning

else # CREATE is set - full add mechanism from filesystem (without parsing an rsync log)
	cd "$rsync_target"

	no_of_adds=1

	while IFS= read -r -d $'\0' filename; do
		# remove './' in the beginning of the path
		raw_filepath=$(echo "$filename" | sed 's/^\.\///g')
		
		if [[ $filename == *"/~"* ]]; then
			warn "Skipped file with '/~' in path: $filename"
			continue
		elif [[ $filename == *"/."* ]]; then
			warn "Skipped hidden file/folder: $filename"
			continue
		fi
		
		new_filepath=$(rewrite_log_path "$raw_filepath")
		mfs_filepath="/$ipfs_folder/$new_filepath"
		mfs_parent_folder=$(get_path_wo_fn "$mfs_filepath")
		fs_filepath="${rsync_target}$raw_filepath"
		
		if ipfs_mfs_path_exist "$mfs_filepath"; then
			warn "the file '$new_filepath' was already existing on IPFS, deleting"
			if ! ipfs_mfs_file_rm "$mfs_filepath"; then
				fail "the file '$new_filepath' exists but couldn't be removed from IPFS" 290
			fi
		else
			# ensure the directory (path) exists
			if ! ipfs_mfs_path_exist "$mfs_parent_folder"; then
				if ! ipfs_mfs_mkdir_path "$mfs_parent_folder"; then
					fail "the new file '$new_filepath's folder couldn't be created" 289
				fi
			fi
		fi
			
		ipfs_mfs_add_file "$fs_filepath" "$mfs_filepath"
			
		unset raw_filepath new_filepath mfs_filepath mfs_parent_folder fs_filepath
		
		((no_of_adds % 100)) || echo "$no_of_adds files processed..."
		((no_of_adds++))
	done < <(find . -type f -print0)
	
	# force update after creation
	rm -f "${rsync_target}lastupdate" || true
fi

printf "\n:: sync completed, start publishing @ %s\n" "$(get_timestamp)"

#get new rootfolder CIDs
ipfs_mfs_folder_cid=$(ipfs_api files stat --hash "/$ipfs_folder") || fail 'repo folder (IPFS) CID could not be determined after update is completed' 400

echo -ne ":: publishing new root-cid to DHT..."
ipfs_api dht provide --timeout 3m "$ipfs_mfs_folder_cid" > /dev/null || warn 'Repo folder (IPFS) could not be published to dht after update\n' -n
echo "done."

if [ "$NOCLUSTER" -eq 0 ]; then
	echo -ne ":: adding folder to cluster-pinset..."
	if [ -z "$cluster_pin_frozen_name" ]; then #we haven't run rsync; use current time
		cluster_pin_frozen_name=$(get_frozen_name "$ipfs_folder")
	fi
	echo "done."

	add_clusterpin "$ipfs_mfs_folder_cid" "$cluster_pin_frozen_name" "default" || fail "Repo folder (IPFS) could not be published on the cluster-pinset; CID '$ipfs_mfs_folder_cid'" 999 -n
fi

if [ "$NOIPNS" -eq 0 ]; then
	echo -ne ":: publishing new ipns record..."
	if ! ipfs_api name publish --timeout 3m --resolve=false --allow-offline --ttl '5m' --lifetime '96h' --key="$ipfs_ipns_name" "/ipfs/$ipfs_mfs_folder_cid" > /dev/null; then
		fail 'Repo folder (IPFS) IPNS could not be published after update' 998 -n
	fi
	echo "done."
fi

printf ':: operation successfully completed @ %s\n' "$(get_timestamp)"

if [ $CREATE -eq 0 ]; then
	cat "$rsync_log" >> "$rsync_log_archive" || fail "couldn't cat the rsync log" 977
	rm -f "$rsync_log" || fail "couldn't remove the rsync log" 978
fi
