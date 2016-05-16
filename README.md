# Single Board Computer Image Builder

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
dd if=/dev/mmcblk0 of=./bootloader.img bs=512 count=264192
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
```
