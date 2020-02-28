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


# simple script to follow just one repo (with or without dnslink) and pin/unpin any updates the subpath locally
#
# available arguments:
# --firstrun

# dependencies:
# - a running ipfs
# - need to be run with the same user account which runs the ipfs daemon

### config ###

#timeout for all non-pin operations in seconds
resolve_timeout="120"

#timeout for all pin operations in hours
pin_timeout="24"

# ipfs-ipns repository domain
ipfs_ipns='pkg.pacman.store'

# linux distribution identifier
dist_id='arch'

# architecture identifier
arch_id='x86_64'

# repo identifier
repo_id='default'

# Lockfile path
lock="$HOME/.follow_cluster_parts_${ipfs_ipns}_${dist_id}_${arch_id}_${repo_id}.lock"

# last_cid store
last_cid_file="$HOME/.follow_cluster_parts_${ipfs_ipns}_${dist_id}_${arch_id}_${repo_id}.last_cid"

# last_ipns_cid store
last_ipns_cid_file="$HOME/.follow_cluster_parts_${ipfs_ipns}_${dist_id}_${arch_id}_${repo_id}.last_ipns_cid"

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

[ -z "$ipfs_ipns" ] && fail "IPFS ipns config string is empty" 20
[ -z "$resolve_timeout" ] && fail "IPFS resolve timeout config string is empty" 21
[ -z "$pin_timeout" ] && fail "IPFS resolve timeout config string is empty" 22
[ -z "$dist_id" ] && fail "distribution identifier config string is empty" 23
[ -z "$arch_id" ] && fail "architecture identifier config string is empty" 24
[ -z "$repo_id" ] && fail "repository identifier config string is empty" 25
[ -z "$last_cid_file" ] && fail "last_cid file config string is empty" 26
[ -z "$last_ipns_cid_file" ] && fail "last_ipns_cid_file file config string is empty" 27

if [ "$1" != "--firstrun" ]; then
	[ -f "$last_cid_file" ] || fail "last_cid file could not be found" 30
	[ -f "$last_ipns_cid_file" ] || fail "last_ipns_cid_file file could not be found" 31
else
	echo "0" > "$last_cid_file"
	echo "0" > "$last_ipns_cid_file"
fi

last_cid=$(cat "$last_cid_file")
last_ipns_cid=$(cat "$last_ipns_cid_file")

echo -ne "receiving CID for IPNS, ipns: $ipfs_ipns..."
if ! cur_root_cid=$(ipfs name resolve --timeout "${resolve_timeout}s" --recursive --nocache "/ipns/$ipfs_ipns"); then
	fail "could not resolve ipns '$ipfs_ipns'"  40 -n
else
	echo "completed."
fi

if [ "$last_ipns_cid" == "$cur_root_cid" ]; then
	echo "nothing to do: ipns-cid is still up to date"
	exit 0
fi

echo -ne "accessing CID of IPNS subdirectory..."
if ! ipfs ls --timeout "${resolve_timeout}s" "$cur_root_cid" > /dev/null; then
	fail "could not find specified folder on ipns '$ipfs_ipns'"  41 -n
else
	echo "completed."
fi

echo -ne "receiving CID for IPNS subdirectory, path './$dist_id/$arch_id/$repo_id/'..."
if ! cur_cid=$(ipfs ls --timeout "${resolve_timeout}s" "$cur_root_cid/$dist_id/$arch_id/" | grep " - $repo_id/" | cut -d ' ' -f1); then
	fail "could not find specified folder on ipns '$ipfs_ipns'"  41 -n
else
	echo "completed."
fi

if [ "$last_cid" == "$cur_cid" ]; then
	echo "nothing to do: ipfs folder cid is still up to date"
	exit 0
fi

if [ "$last_cid" == "0" ]; then
	echo "pinning new version, cid: $cur_cid..."
	if ! ipfs pin add --recursive --progress --timeout "${pin_timeout}h" "/ipfs/$cur_cid"; then
		fail "pinning could not be completed" 50 -n
	else
		echo "completed."
	fi
else
	echo "updating pin to new version, cid: $cur_cid..."
	if ! ipfs pin update --timeout "${pin_timeout}h" "/ipfs/$last_cid" "/ipfs/$cur_cid"; then
		fail "pinning could not be completed" 50 -n
	else
		echo "completed."
	fi

fi

echo "$cur_cid" > "$last_cid_file"
echo "$cur_root_cid" > "$last_ipns_cid_file"

