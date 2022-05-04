_The toolset has been split off and is now [here](https://github.com/RubenKelevra/rsync2ipfs-cluster.git) available._

# pacman.store

**Current status and any announcements, as well as a maintenance log, can be found [here](https://github.com/RubenKelevra/pacman.store/wiki/Status,-Announcements-&-Maintenance)**

Under the domain pacman.store are [package mirrors](https://wiki.archlinux.org/index.php/Pacman#Repositories_and_mirrors) provided via the [IPFS-Network](https://ipfs.io). If you choose this as your mirror, Pacman will download the files from a local http-proxy and the accessed files will be shared with the IPFS-Network.

If you run on multiple machines in your local network IPFS will exchange the files locally rather than downloading the same file multiple times from the internet.

The data is held and shared by a collaborative cluster, which is provided by volunteers.

## Usage

### Install IPFS as a service:

Install [`ipfs`](https://wiki.archlinux.org/index.php/IPFS) on each of your systems - I recommend my AUR package [go-ipfs-git](https://aur.archlinux.org/packages/go-ipfs-git) which uses the hardened service file.

Start the service with:

```console
# systemctl enable --now ipfs
```

### IPFS configuration

I recommend enabling the build-in router module gossipsub which accelerates the lookup of names, like "pacman.store" significantly:

```console
# su ipfs -c /bin/bash -c "ipfs config Pubsub.Router gossipsub"
```

_Note: If you don't use my AUR package go-ipfs-git, make sure to modify your service file to include `--enable-pubsub-experiment`, `--enable-namesys-pubsub`, and `--enable-gc` on the ipfs-daemon._
- _`--enable-pubsub-experiment --enable-namesys-pubsub` will speedup name-lookups_
- _`--enable-gc` runs the garbage collection automatically, otherwise IPFS will never clean up its storage_

Ipfs uses by default up to 10 GB of disk space in /var/lib/ipfs. If you want to lower or increase this value, you can do this by:

```console
# su ipfs -c /bin/bash -c "ipfs config Datastore.StorageMax '10GB'"
```

After changing the settings you need to restart the daemon with 

```console
# systemctl restart ipfs
```

### General Pacman config

It makes sense to set the parallel downloads to two and disable the download timeout, to avoid unnecessary aborts if ipfs needs initially a bit more time to find the right peers in the network (especially on high latency internet connections).

Add the following lines to your pacman config (misc config section):

```
DisableDownloadTimeout
ParallelDownloads = 2
```

### Repositories

#### Archlinux

Add to the top of `/etc/pacman.d/mirrorlist`:
```
# IPFS
Server = http://x86-64.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo
Server = http://x86-64.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo
Server = http://x86-64.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo
```

#### Chaotic-AUR

After following the regular chaotic-aur installation procedure, add these lines to the top of `/etc/pacman.d/chaotic-mirrorlist`:
```
# IPFS
Server = http://chaotic-aur.pkg.pacman.store.ipns.localhost:8080/$arch
Server = http://chaotic-aur.pkg.pacman.store.ipns.localhost:8080/$arch
Server = http://chaotic-aur.pkg.pacman.store.ipns.localhost:8080/$arch
```

#### ALHP

After following the regular alhp installation procedure, add these lines to the top of `/etc/pacman.d/alhp-mirrorlist`:
```
# IPFS
Server = http://alhp.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo/os/$arch/
Server = http://alhp.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo/os/$arch/
Server = http://alhp.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo/os/$arch/
```

#### Endeavouros

Add to the top of `/etc/pacman.d/mirrorlist`:
```
# IPFS
Server = http://x86-64.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo
Server = http://x86-64.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo
Server = http://x86-64.archlinux.pkg.pacman.store.ipns.localhost:8080/$repo
```

Add to the top of `/etc/pacman.d/endeavouros-mirrorlist`

```
# IPFS
Server = http://endeavouros.pkg.pacman.store.ipns.localhost:8080/repo/$repo/$arch
Server = http://endeavouros.pkg.pacman.store.ipns.localhost:8080/repo/$repo/$arch
Server = http://endeavouros.pkg.pacman.store.ipns.localhost:8080/repo/$repo/$arch
```

#### Manjaro

Add to the top of `/etc/pacman.d/mirrorlist`:
```
# IPFS
Server = http://manjaro.pkg.pacman.store.ipns.localhost:8080/stable/$repo/$arch
Server = http://manjaro.pkg.pacman.store.ipns.localhost:8080/stable/$repo/$arch
Server = http://manjaro.pkg.pacman.store.ipns.localhost:8080/stable/$repo/$arch
```

#### Manjaro (ARM)

Add to the top of `/etc/pacman.d/mirrorlist`:
```
# IPFS
Server = http://manjaro.pkg.pacman.store.ipns.localhost:8080/arm-stable/$repo/$arch
Server = http://manjaro.pkg.pacman.store.ipns.localhost:8080/arm-stable/$repo/$arch
Server = http://manjaro.pkg.pacman.store.ipns.localhost:8080/arm-stable/$repo/$arch
```



## Cluster members


| Member ID | Server | Location | Internet-Provider | AS | Provider |
| - | - | - | - | - | - |
| `12D3KooWDM4BGmkaxhLtEFbQJekdBHtWHo3ELUL4HE9f4DdNbGZx` | `odin.pacman.store` | Nuremberg, Germany | netcup | AS197540 | [@RubenKelevra](https://github.com/RubenKelevra) |
| `123...` | | Guthrie, Oklahoma | Cox Communications Inc | AS22773 | [@teknomunk](https://github.com/teknomunk) |
| `12D3KooWGCSifNrJPZPfEdhAjRtxCW2dukiqQEqg4RAV6hE2jgbA` | `vidar.pacman.store` | Vilnius, Lithuania | UAB Interneto vizija | AS20080814 | [@RubenKelevra](https://github.com/RubenKelevra) |
| `123...` | | ~ Tokyo, Japan | | AS7506 | _anonymous_ |
| `12D3KooWBqQrnTqx9Wp89p2bD1hrwmXYJQ5x1fDfigRCfZJGKQfr` | `luflosi.de` | Saarland, Germany | VSE NET GmbH | AS9063 | [@Luflosi](https://github.com/Luflosi) |


## Import Server uptime (last month)

| Service | Status |
| - | - |
| IPv6 | <img src="https://app.statuscake.com/button/index.php?Track=lqm087FDpT&Days=30&Design=2" /> |
| IPv4 | <img src="https://app.statuscake.com/button/index.php?Track=mdwVReU662&Days=30&Design=2" /> |
| IPFS-Port | <img src="https://app.statuscake.com/button/index.php?Track=dpSNJkhpBi&Days=30&Design=2" /> |
| IPFS-Cluster-Port | <img src="https://app.statuscake.com/button/index.php?Track=W6VTSzFRsc&Days=30&Design=2" /> |

## Join the Cluster

If you want to join and contribute bandwidth and disk space, feel free to do so. The repo size is about 280 GB. Since the data is rotating quite quickly it's recommended to enable the Garbage Collector with `--enable-gc` for your IPFS-Daemon.

The default storage size for IPFS needs to be altered in the config file.

If you're running your cluster follower on a computer with a static IP or a static domain name: Feel free to add it to the list of ```peer_addresses``` in the JSON config files, found in [collab-cluster-config](./collab-cluster-config). Then send a pull request.

Details on how to join the cluster are available on the [collab cluster](https://collab.ipfscluster.io/) website.

*tl;dr:* You need a locally running IPFS node. Your IPFS *StorageMax* setting may need to be adjusted. You need [ipfs-cluster-follow](https://aur.archlinux.org/packages/ipfs-cluster-bin/), then run:

```console
ipfs-cluster-follow pkg.pacman.store run --init cluster.pkg.pacman.store
```

On low power machines use the following command:

```console
ipfs-cluster-follow pkg.pacman.store run --init lowpower.cluster.pkg.pacman.store
```

## FAQ

If you have any questions, feel free to ask in the [IPFS-chat on matrix](https://riot.im/app/#/room/#ipfs:matrix.org), after consulting the [FAQ](https://github.com/RubenKelevra/pacman.store/wiki/FAQ)

## Get an ISO/bootstrap image from IPFS

ISO and bootstrap files are also stored on the cluster:

[ArchLinux ISO/bootstrap images](http://x86-64.archlinux.pkg.pacman.store/iso)

---

| IPFS-URL | Content |
| - | - |
| `/ipns/cluster.pkg.pacman.store` | cluster setup domain which holds the config file |
| `/ipns/x86-64.archlinux.pkg.pacman.store/` | regular archlinux mirror<br>(without '/os/x86_64/' subfolders in path) |
| `/ipns/x86-64.archlinux.pkg.pacman.store/iso/` | current ArchLinux ISO+bootstrap images |
| `/ipns/endeavouros.pkg.pacman.store/` | regular Endeavouros mirror |
| `/ipns/manjaro.pkg.pacman.store/` | regular Manjaro mirror<br>(without staging/unstable/testing) |
