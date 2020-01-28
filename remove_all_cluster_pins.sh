#!/bin/bash

set -e

# purpose of this script is to remove all pins of a ipfs-cluster

while IFS= read -r -d $'\n' pin; do
	ipfs-cluster-ctl pin rm --no-status "$pin"
done < <(ipfs-cluster-ctl pin ls | cut -d ' ' -f 1)


