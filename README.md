# pacman.store

The domain [pkg.pacman.store](http://pkg.pacman.store) offers pkgs for Pacman you can mount to access it as Pacman cache through your local IPFS daemon. All files accessed this way will be downloaded to your IPFS cache and shared with the network.

If you run on multiple machines in your local network IPFS will exchange the files locally rather than downloading the same file multiple times from the internet.

The data is hold and shared by a collaborative cluster, where everyone can participate.

## Cluster members


| Server | Location | Provider | AS | 
| - | - | - | - |
| `loki.pacman.store` | Nuremberg, Germany | netcup | AS197540 | 
| _third-party_ | Guthrie, Oklahoma | Cox Communications Inc. | AS22773 |
| `vidar.pacman.store` | Vilnius, Lithuania | UAB Interneto vizija | AS20080814 |
| `heimdal.pacman.store` | Mumbai, India | Oracle Corporation | AS31898 |


## Join the Cluster

If you want to join and contribute bandwidth and hard drive space, feel free to do so. The repo-size is about 70 GB. Since the data is rotating quite quickly it's recommended to enable the Garbage Collector with `--enable-gc` for your IPFS-Daemon.

The default storage size for IPFS needs to be altered in the config file.

If you're running your cluster follower on a computer with a static ip or a static domain name: Feel free to add it to the list of ```peer_addresses``` in the JSON config files, found in [collab-cluster-config](./collab-cluster-config). Then send a pull request.

Details how to join the cluster are available on the [collab cluster](https://collab.ipfscluster.io/) website.

*tl;dr:* You need a locally running IPFS node. Your IPFS *StorageMax* setting may needs to be adjusted. You need [ipfs-cluster-follow](https://aur.archlinux.org/packages/ipfs-cluster-bin/), then run:

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

---

| IPFS-URL | Content |
| - | - |
| `/ipns/cluster.pacman.store` | cluster setup domain which holds the config file |
| `/ipns/pkg.pacman.store/arch/x86_64/default/` | regular mirror (plus `cache` and `db` subfolders) |
| `/ipns/pkg.pacman.store/arch/x86_64/default/cache/` | current Pacman pkgs for ArchLinux (all standard repos + testing/staging) |
| `/ipns/pkg.pacman.store/arch/x86_64/default/db/` | current Pacman databases for ArchLinux  (all standard repos + testing/staging) |
| `/ipns/iso.pacman.store/arch/x86_64/default/` | current ArchLinux ISO+bootstrap images |
