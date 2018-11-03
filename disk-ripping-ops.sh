# Ripping two partions into one image file

## Layouts

```
fdisk -l pocketcluster-devel-arm64-pine64-xenial-2017-01-30.img

Disk pocketcluster-devel-arm64-pine64-xenial-2017-01-30.img: 820 MiB, 859832320 bytes, 1679360 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x6dbb8bf7

Device                                                  Boot  Start     End Sectors  Size Id Type
pocketcluster-devel-arm64-pine64-xenial-2017-01-30.img1 *     40960  143359  102400   50M  c W95 FAT32 (LBA)
pocketcluster-devel-arm64-pine64-xenial-2017-01-30.img2      143360 1679359 1536000  750M 83 Linux
```

```
fdisk -l pine64-plus-stretch-mainline-20171015.img

Disk pine64-plus-stretch-mainline-20171015.img: 4 GiB, 4294967296 bytes, 8388608 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x457797df

Device                                     Boot  Start     End Sectors  Size Id Type
pine64-plus-stretch-mainline-20171015.img1        2048  264191  262144  128M 83 Linux
pine64-plus-stretch-mainline-20171015.img2      264192 8388607 8124416  3.9G 83 Linux

- - -

```sh
dd if=./pine64-plus-stretch-mainline-20171015.img of="./PINE64-4.14.23-DIRTY.img" bs=512 count=264192

# https://stackoverflow.com/questions/20526198/why-using-conv-notrunc-when-cloning-a-disk-with-dd
# https://superuser.com/questions/850267/how-to-append-data-in-a-file-by-dd
# `skip` moves current pointer of the input stream |  `seek` moves current pointer in the output stream.
# choose one of command below
# 
dd if=./pine64-plus-stretch-mainline-20171015.img of="./PINE64-4.14.23-DIRTY.img" bs=512 skip=143360 seek=264192 count=1536000 
dd if=./pocketcluster-devel-arm64-pine64-xenial-2017-01-30.img of="./PINE64-4.14.23-DIRTY.img" bs=512 skip=143360 seek=264192 oflag=append conv=notrunc
dd if=./pocketcluster-devel-arm64-pine64-xenial-2017-01-30.img of="./PINE64-4.14.23-DIRTY.img" bs=512 skip=143360 >>./PINE64-4.14.23-DIRTY.img

sfdisk -f PINE64-4.14.23-DIRTY.img <<EOM
unit: sectors
1 : start=     2048, size= 262144,  Id=83, bootable
2 : start=   264192, size= 1536000, Id=83
3 : start=        0, size=       0, Id= 0
EOM
```

- - -

```sh
export BOOT_LOOP="$(losetup --offset $((2048 * 512)) --sizelimit $((264192 * 512)) -f --show ${PWD}/PINE64-4.14.23-DIRTY.img)"
export BOOT_MOUNT="/tmp/boot"
mount "${BOOT_LOOP}" "${BOOT_MOUNT}"

# do something

umount -l "${BOOT_MOUNT}"
losetup -d "${BOOT_LOOP}"


export ROOTFS_LOOP="$(losetup --offset $((264192 * 512)) --sizelimit $((1536000 * 512)) -f --show ${PWD}/PINE64-4.14.23-DIRTY.img)"
export ROOTFS_MOUNT="/tmp/rootfs"
mount "${ROOTFS_LOOP}" "${ROOTFS_MOUNT}"

# do something

umount -l "${ROOTFS_MOUNT}"
losetup -d "${ROOTFS_LOOP}"
```