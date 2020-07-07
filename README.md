# pacman.store

**Current status and any announcements as well as a maintaince log can be found [here](https://github.com/RubenKelevra/pacman.store/wiki/Status,-Announcements-&-Maintenance)**

Under the domain pacman.store are [package mirrors](https://wiki.archlinux.org/index.php/Pacman#Repositories_and_mirrors) provided via the [IPFS-Network](https://ipfs.io). If you choose this as your mirror, Pacman will download the files from a local http-proxy and the accessed files will be shared with the IPFS-Network.

If you run on multiple machines in your local network IPFS will exchange the files locally rather than downloading the same file multiple times from the internet.

The data is hold and shared by a collaborative cluster, where everyone can participate.

## Cluster members


| Member ID | Server | Location | Internet-Provider | AS | Provider |
| - | - | - | - | - | - |
| `12D3KooWDM4BGmk...` | `odin.pacman.store` | Nuremberg, Germany | netcup | AS197540 | [@RubenKelevra](https://github.com/@RubenKelevra) |
| `123...` | `loki.pacman.store` | Nuremberg, Germany | netcup | AS197540 | [@RubenKelevra](https://github.com/@RubenKelevra) |
| `123...` | | Guthrie, Oklahoma | Cox Communications Inc | AS22773 | [@teknomunk](https://github.com/teknomunk) |
| `123...` | `vidar.pacman.store` | Vilnius, Lithuania | UAB Interneto vizija | AS20080814 | [@RubenKelevra](https://github.com/@RubenKelevra) |
| `12D3KooWN9pSnzm...` | `heimdal.pacman.store` | Mumbai, India | Oracle Corporation | AS31898 | [@RubenKelevra](https://github.com/@RubenKelevra) |
| `123...` | | ~ Tokyo, Japan | | AS7506 | _anonymous_


## Import Server uptime (since 2020-07-02)

| Service | Status |
| - | - |
| IPv6 | <img src="https://app.statuscake.com/button/index.php?Track=lqm087FDpT&Days=1000&Design=2" /> |
| IPv4 | <img src="https://app.statuscake.com/button/index.php?Track=mdwVReU662&Days=1000&Design=2" /> |
| IPFS-Port | <img src="https://app.statuscake.com/button/index.php?Track=dpSNJkhpBi&Days=1000&Design=2" /> |
| IPFS-Cluster-Port | <img src="https://app.statuscake.com/button/index.php?Track=WxV3J9md1R&Days=1000&Design=2" /> |

## Join the Cluster

If you want to join and contribute bandwidth and disk space, feel free to do so. The repo-size is about 70 GB. Since the data is rotating quite quickly it's recommended to enable the Garbage Collector with `--enable-gc` for your IPFS-Daemon.

The default storage size for IPFS needs to be altered in the config file.

If you're running your cluster follower on a computer with a static ip or a static domain name: Feel free to add it to the list of ```peer_addresses``` in the JSON config files, found in [collab-cluster-config](./collab-cluster-config). Then send a pull request.

Details how to join the cluster are available on the [collab cluster](https://collab.ipfscluster.io/) website.

*tl;dr:* You need a locally running IPFS node. Your IPFS *StorageMax* setting may needs to be adjusted. You need [ipfs-cluster-follow](https://aur.archlinux.org/packages/ipfs-cluster-bin/), then run:

```ipfs-cluster-follow pkg.pacman.store run --init cluster.pkg.pacman.store```

## Use the pkg cache with Pacman

Install [`ipfs`](https://wiki.archlinux.org/index.php/IPFS) on each of your systems, you need set it up and and start it as a service.

Then add the following to your `/etc/pacman.d/mirrorlist` as first entry:
```
# IPFS
Server = http://x86-64.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo
```

Since directory lookups may be slower over IPNS, you may need to set the pacman option `--disable-download-timeout` for fetching dbs or packages.

## FAQ

If you have any questions, feel free to ask in the [IPFS-chat on matrix](https://riot.im/app/#/room/#ipfs:matrix.org), after consulting the [FAQ](https://github.com/RubenKelevra/pacman.store/wiki/FAQ)

## Get an ISO/bootstrap image from IPFS

ISO and bootstrap files are also stored on the cluster:

[ArchLinux ISO/bootstrap images](http://x86-64.archlinux.pkg.pacman.store/iso)

---

| IPFS-URL | Content |
| - | - |
| `/ipns/cluster.pkg.pacman.store` | cluster setup domain which holds the config file |
| `/ipns/x86-64.archlinux.pkg.pacman.store/` | regular mirror (without '/os/x86_64/' subfolders in path) |
| `/ipns/x86-64.archlinux.pkg.pacman.store/iso/` | current ArchLinux ISO+bootstrap images |
