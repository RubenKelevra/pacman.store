# pacman.store

The domain [pkg.pacman.store](http://pkg.pacman.store) offers pkgs for Pacman you can mount to access it as Pacman cache through your local IPFS daemon. All files accessed this way will be downloaded to your IPFS cache and shared with the network.

If you run on multiple machines in your local network IPFS can exchange the files locally rather than downloading the same file multiple times from the internet.

The data is hold and shared by a collaborative cluster, where everyone can participate.

## Join the Cluster

If you want to join and contribute bandwidth and hard drive space, feel free to do so. A 24/7 internet connection will be greatly appreciated.

If you're running your cluster follower on a computer with a static ip or a static domain name: Feel free to add it to the list of ```peer_addresses``` in the JSON config files, found in [collab-cluster-config](./collab-cluster-config). Then send a pull request.

The cluster is listed on the [collab cluster](https://collab.ipfscluster.io/) website.

*tl;dr:* You need a locally running IPFS node. Your IPFS *StorageMax* setting may needs to be adjusted. You need [ipfs-cluster-follow](https://dist.ipfs.io/#ipfs-cluster-follow), then run:

```ipfs-cluster-follow pacman.store run --init cluster.pacman.store```

## Use the pkg cache with Pacman

### Webgateway method:
Install [`ipfs`](https://wiki.archlinux.org/index.php/IPFS) on each of your systems, you need set it up and and start it as a service.

Then add the following to your `/etc/pacman.d/mirrorlist` as first entry:
```
# IPFS
Server = http://127.0.0.1:8080/ipns/pkg.pacman.store/arch/$arch/default/$repo
```

Since directory lookups may be slower over IPNS, you may need to set the pacman option `--disable-download-timeout` for fetching dbs or packages.

## Get an ISO/bootstrap image from IPFS

ISO and bootstrap files are also stored on the cluster:

[ArchLinux ISO/bootstrap images](http://iso.pacman.store/arch/x86_64/default/)

[Manjaro ISO images](http://iso.pacman.store/manjaro/x86_64/)

## Find an old pkg

We hold old pkgs (disappeared from the mirrors) for another 2 weeks as snapshots in the cluster. Older pkgs or snapshots might not be accessible any longer. This depends on the garbage collections on the cluster-members and how long other clients in the network hold the files.

[pkg archive](http://old.pkg.pacman.store/) (access might be slow)

---

| IPFS-URL | Content |
| - | - |
| `/ipns/cluster.pacman.store` | cluster setup domain which holds the config file |
| `/ipns/pkg.pacman.store/arch/x86_64/default/` | current Pacman pkgs for ArchLinux (all standard repos + testing/staging) |
| `/ipns/pkg.pacman.store/arch/x86_64/default/db/` | current Pacman databases for ArchLinux  (all standard repos + testing/staging) |
| `/ipns/old.pkg.pacman.store/arch/x86_64/default` | list-file of snapshots of the Pacman pkgs for ArchLinux with ISO-8601-Timestamp (all standard repos + testing/staging/unstable) |
| `/ipns/iso.pacman.store/arch/x86_64/default/` | current ArchLinux ISO+bootstrap images |
| `/ipns/iso.pacman.store/manjaro/x86_64/` | current Manjaro ISO images |
















