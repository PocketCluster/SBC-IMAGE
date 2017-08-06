# Raspberry PI3 64bit Image Builder V2 (ARMv7)

We build RPI images with Mate bootloader. This is most standard, straight forward way we can expect for baking image. Bootloader is donwloaded as deb package, and we will keep using for RPI3 support.

Current build is based on Xenial 16.04.1

**`build-settings.sh`**

Build setting such as distro, directory, version & etc.   

## Distribution

**`build-dist-filetree.sh`**

Distribution file tree. Base `Xenial` image is in `/POCKET/SBC-IMG-BUILDER/RPI`.  

**`make-dist-image.sh`**

Make dist image.  

## Development

**`build-devel-filetree.sh`**

Development file tree. This will include more packages. Base `Xenial` image is in `/POCKET/SBC-IMG-BUILDER/RPI`.   

**`make-devel-image.sh`**

Make devel image.  

## SUSE image layout

```sh
fdisk -l openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw

Disk openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw: 1.5 GiB, 1647312896 bytes, 3217408 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x9e3bee2f

Device                                               Boot  Start     End Sectors  Size Id Type
openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw1        2048  411651  409604  200M  c W95 FAT32 (LBA)
openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw2      413696 3217280 2803585  1.3G 83 Linux
```

### File Preview
```
# Bootsection (be careful with sizelimit. It takes 'size', not end sector)
export BOOT_LOOP="$(losetup --offset $((2048 * 512)) --sizelimit $((409604 * 512)) -f --show ${PWD}/openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw)"
export BOOT_MOUNT="/tmp/boot"
mount "${BOOT_LOOP}" "${BOOT_MOUNT}"

...

umount -l "${BOOT_MOUNT}"
losetup -d "${BOOT_LOOP}"

# Rootfs (be careful with sizelimit. It takes 'size', not end sector)
export ROOTFS_LOOP="$(losetup --offset $((413696 * 512)) --sizelimit $((2803585 * 512)) -f --show ${PWD}/openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw)"
export ROOTFS_MOUNT="/tmp/rootfs"
mount "${ROOTFS_LOOP}" "${ROOTFS_MOUNT}"

umount -l "${ROOTFS_MOUNT}"
losetup -d "${ROOTFS_LOOP}"
```

### Ripping

```
dd if=./openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw of="./BOOTLOADER-RPI64-OSUSE-Leap42.2-20170806.img" bs=512 count=411652

mount -o ro,loop,offset=$((413696 * 512)) ${PWD}/openSUSE-Leap42.2-ARM-JeOS-raspberrypi3.aarch64.raw /mnt

cd /mnt
tar cvzf /media/sf_workspace/BOOTDIR-RPI64-OSUSE-Leap42.2-20170806.tar.gz boot
tar cvzf /media/sf_workspace/FIRMWARE-RPI64-OSUSE-Leap42.2-20170806.tar.gz lib/firmware
tar cvzf /media/sf_workspace/MODULES-RPI64-OSUSE-Leap42.2-20170806.tar.gz lib/modules/4.4.74-18.20-default
```


## CONFIG_VXLAN Option

For this option, please update rpi-firmware at least to `4.4.22-v7+`. or

```sh
rpi-update d26c39bd353eb0ebbc7db3546277083eac4aa3bd
```

> References

- [pre-compiled binaries of the current Raspberry Pi kernel and modules](https://github.com/raspberrypi/firmware)
- [Firmware files for the Raspberry Pi](https://github.com/Hexxeh/rpi-firmware)
- [An easier way to update the firmware of your Raspberry Pi](https://github.com/Hexxeh/rpi-update)
- <https://github.com/Evilpaul/RPi-config>