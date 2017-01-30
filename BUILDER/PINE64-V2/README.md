# How to remove junk in boot sector

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