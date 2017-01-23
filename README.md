# Single Board Computer Image Builder

## DOCKER OPTIONS

Docker options must be fully satisfied. Look [Kernel](KERNEL/README.md) for detail.  
For Swarm cluster to have `overlay` network, we need `CONFIG_VXLAN` in kernel option. (CRITICAL)

- [vxlan module](DOCUMENT/kernel-bridge-and-vxlan)
- [No route to host / connection refused - swarm mode on ARM #25892](https://github.com/docker/docker/issues/25892)

## Build Process  

Firstly `rsync` [BUILDER](/BUILDER) and `/POCKET/UBUNTU-BUILDER/BUILDER` for base files.  

## Ripping Bootloaders  

### Ripping Odroid-C2 Bootloader  

```sh
$ fdisk -l

Disk /dev/mmcblk0: 29.7 GiB, 31914983424 bytes, 62333952 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xd3630000

Device         Boot  Start      End  Sectors  Size Id Type
/dev/mmcblk0p1        2048   264191   262144  128M  c W95 FAT32 (LBA)
/dev/mmcblk0p2      264192 62332928 62068737 29.6G 83 Linux

# grep the begining of root partition
$ dd if=/dev/mmcblk0 of=./BOOTLOADER-C2-3.14.29-56.img bs=512 count=264192
```

**Recovering broken bootloader**

<sup>*</sup> Be aware of restoring target. It is a __DEVICE__, not a partition.

```sh
$ dd if=./BOOTLOADER-C2-3.14.29-56.img if=/dev/<device_name> bs=512 count=264192
```

### Ripping Pine-64 Bootloader

```sh
$ fdisk -l

Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0xdce985d5

Device         Boot  Start      End  Sectors  Size Id Type
/dev/mmcblk0p1       40960   143359   102400   50M  c W95 FAT32 (LBA)
/dev/mmcblk0p2      143360 15138815 14995456  7.2G 83 Linux

# grep the begining of root partition
$ dd if=/dev/mmcblk0 of=./BOOTLOADER-PINE64-3.10.65-7-LONGSLEEP.img bs=512 count=143360
```

**Recovering broken bootloader**

<sup>*</sup> Be aware of restoring target. It is a __DEVICE__, not a partition.

```sh
$ dd if=./BOOTLOADER-PINE64-3.10.65-7-LONGSLEEP.img if=/dev/<device_name> bs=512 count=143360
```

### Ripping RPI 2/3 Bootloader

```sh
$ fdisk -l

Disk /dev/mmcblk0: 29.7 GiB, 31914983424 bytes, 62333952 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x9842f678

Device         Boot  Start     End Sectors  Size Id Type
/dev/mmcblk0p1 *      2048  133119  131072   64M  c W95 FAT32 (LBA)
/dev/mmcblk0p2      133120 1566719 1433600  700M 83 Linux

# grep the begining of root partition
$ dd if=/dev/mmcblk0 of=./BOOTLOADER-RPI.img bs=512 count=133120
```

**Recovering broken bootloader**

<sup>*</sup> Be aware of restoring target. It is a __DEVICE__, not a partition.

```sh
$ dd if=./BOOTLOADER-RPI.img if=/dev/<device_name> bs=512 count=133120
```

## Where to get base/core Ubuntu Daily build

### Ubuntu Xenial Base (Dist Build)  

[`Ubuntu Base`](DOCUMENT/Ubuntu Base 16-04 (Xenial Xerus) Daily Build.pdf)  
- <http://cdimage.ubuntu.com/ubuntu-base/xenial/>

### Ubuntu Xenial Core (Devel Build)

[`Ubuntu Core`](DOCUMENT/Ubuntu Core 16-04 (Xenial Xerus) Daily Build.pdf)  
- <http://cdimage.ubuntu.com/ubuntu-core/xenial/>

