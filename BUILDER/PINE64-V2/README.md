# Pine64 Image Builder V2

**The development build process is substantially different from RPI or ODROID that it is smaller and less feature complete**

We have faced a couple of issues.

- Bootloader looks for specific root file system boundary such that if rootfs is bigger than certain limit, bootloader refuses to boot. 
  - *This issue can be mitigated by shringking image size.
  - V2 bootloader is ripped from `xubuntu-xenial-mate-20161215-longsleep-pine64-8GB.img.gz`
- `3.10.104` does not support `CONFIG_VXLAN` out of box. _Kernel compile required_  
- `/lib/firmware` contains unrelated stuffs to PINE64
- `/lib/modules/3.10.104` is way too big
- `eth0` mac address is hard-coded in `/boot/uEnv.txt`. 

  > ethaddr=ba:88:8e:64:aa:78
- Cannot acquire partition table properly from fdisk. (i.e. the first sector is 2048 wherever you start)

Current build is based on Xenial 16.04.1. 

**`build-settings.sh`**

Build setting such as distro, directory, version & etc.   

## Distribution

**`build-dist-filetree.sh`**

Distribution file tree. Image is in `/POCKET/SBC-IMG-BUILDER/PINE64`.  

**`make-dist-image.sh`**

Make dist image.  

## Development

**`build-devel-filetree.sh`**

Development file tree. This will include more packages. Image is in `/POCKET/SBC-IMG-BUILDER/PINE64`.   

**`make-devel-image.sh`**

Make devel image.  

## CONFIG_VXLAN Option

Unsupported as of `3.10.104`

## How to remove junk in boot sector

```sh
# check where to start and where to end
$ fdisk -l BOOTLOADER-PINE64-3.10.104-2017-01-30.img

Disk BOOTLOADER-PINE64-3.10.104-2017-01-30.img: 70 MiB, 73400320 bytes, 143360 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x2b51fa93

Device                                     Boot  Start      End  Sectors  Size Id Type
BOOTLOADER-PINE64-3.10.104-2017-01-30.img1       40960   143359   102400   50M  c W95 FAT32 (LBA)
BOOTLOADER-PINE64-3.10.104-2017-01-30.img2      143360 15138815 14995456  7.2G 83 Linux


export BOOT_LOOP="$(losetup --offset $((40960 * 512)) --sizelimit $((143360 * 512)) -f --show ${PWD}/BOOTLOADER-PINE64-3.10.104-2017-01-30.img)"
export BOOT_MOUNT="${PWD}/boot"
mount "${BOOT_LOOP}" "${BOOT_MOUNT}"

... delete, remove, modify whatever you want...

umount -l "${BOOT_MOUNT}"
losetup -d "${BOOT_LOOP}"
```
