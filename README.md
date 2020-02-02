# pacman.store

The domain [pkg.pacman.store](http://pkg.pacman.store) offers pkgs for Pacman you can mount to access it as Pacman cache through your local IPFS daemon. All files accessed this way will be downloaded to your IPFS cache and shared with the network.

If you run on multiple machines in your local network IPFS can exchange the files locally rather than downloading the same file multiple times from the internet.

The data is hold and shared by a collaborative cluster, where everyone can participate.

## Join the Cluster

If you want to join and contribute bandwidth and hard drive space, feel free to do so. A 24/7 internet connection will be greatly appreciated.

The cluster will be listed on the [collab cluster](https://collab.ipfscluster.io/) website.

*tl;dr:* You need a locally running IPFS node. Your IPFS *StorageMax* setting may needs to be adjusted. You need [ipfs-cluster-follow](https://dist.ipfs.io/#ipfs-cluster-follow), then run: ```ipfs-cluster-follow cluster.pacman.store run --init cluster.pacman.store```


## Use the pkg cache with Pacman

*TBA*

## Get an ISO/bootstrap image from IPFS

ISO and bootstrap files are also stored on the cluster:

[ArchLinux ISO/bootstrap images](http://iso.pacman.store/arch/x86_64/default/)

## Find an old pkg

*Before you use a pkg, make sure to read the WARNING.txt!*

We hold old pkgs (disappeared from the mirrors) for another 2 month as snapshots in the cluster. Corresponding db snapshots can be found in the *db* subfolder. Older pkgs might not be accessible any longer. This depends on the garbage collections on the cluster-members and how long other clients in the network hold the files.

If you want to keep a snapshot indefinitely, feel free to do so. Just pin the timestamp-subfolder in your client.



[pkg archive](http://old.pkg.pacman.store/) (listing will be SLOW)


---

| IPFS-URL | Content |
| - | - |
| `/ipns/cluster.pacman.store` | cluster setup domain |
| `/ipns/pkg.pacman.store/arch/x86_64/default/` | current Pacman pkgs for ArchLinux (all standard repos + testing/staging) |
| `/ipns/pkg.pacman.store/arch/x86_64/default/db/` | current Pacman databases for ArchLinux  (all standard repos + testing/staging) |
| `/ipns/old.pkg.pacman.store/{ISO-8601-Timestamp}/` | archive of Pacman pkgs for ArchLinux  (all standard repos + testing/staging) |
| `/ipns/iso.pacman.store/arch/x86_64/default/` | current ArchLinux ISOs+bootstrap images |
















