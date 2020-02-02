# pacman.store

The domain [pkg.pacman.store](http://pkg.pacman.store) offers an unofficial pacman cache for ArchLinux. You can mount this cache and access it through your local IPFS daemon. All files accessed this way will be downloaded to your IPFS cache and shared with the network.

If you run multiple machines in your local network, they can exchange their cache content rather than downloading the same file multiple times from the internet.

This setup runs on a collaborative clusters, not only my machines will hold and send the pkgs to you, but everyone who is part of the cluster.

## Join the Cluster

If you want to join and contribute bandwidth and hard drive space, feel free to do so. The cluster will be listed on the [collab cluster](https://collab.ipfscluster.io/) website.

*TL;DR:*

Your IPFS cache size needs to be adjusted, you need ipfs-cluster-follow, then run:

```ipfs-cluster-follow cluster.pacman.store run --init cluster.pacman.store```

## Use the pkg cache with Pacman

*TBA*

## Get an ISO/bootstrap image from IPFS

All currently available ISOs and bootstrap files for ArchLinux are also stored on the cluster:

[ArchLinux ISO](http://iso.pacman.store/arch/x86_64/default/)

## Find an old pkg

*Before you use a pkg, make sure to read the WARNING.txt!*

We hold old pkgs (disappeared from the mirrors) for another 2 month as snapshots in the cluster. Corrisponding db snapshots can be found in the *db* subfolder. Older pkgs might not be accessible any longer. This depends on the garbage collections on the cluster-members and how long other clients in the network hold the files.

If you want to keep a snapshot indefinitely, feel free to do so. Just pin the timestamp subfolder in your client.



[pkg archive](http://old.pkg.pacman.store/)


---

| IPFS-URL | Content |
| - | - |
| `/ipns/cluster.pacman.store` | cluster setup domain |
| `/ipns/pkg.pacman.store/arch/x86_64/default/` | current ArchLinux pacman pkgs (all standard repos + testing/staging) |
| `/ipns/pkg.pacman.store/arch/x86_64/default/db/` | current ArchLinux pacman databases (all standard repos + testing/staging) |
| `/ipns/old.pkg.pacman.store/{ISO-8601-Timestamp}/` | archive of ArchLinux pacman pkgs (all standard repos + testing/staging) |
| `/ipns/iso.pacman.store/arch/x86_64/default/` | current ArchLinux ISOs |
















