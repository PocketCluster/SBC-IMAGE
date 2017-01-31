# Odroid-C2 Minified Image Builder (ARM64)

We'll use Hardkernel's bootloader, fstab, firmware, and modules. Most of building process is shared with RPI and very straight-forward, and forgiving. 

Current build is based on Xenial 16.04.1

### `minified-settings.sh`  

Build setting such as distro, directory, version & etc.   

## Distribution

**`minified-dist-filetree.sh`**

Distribution file tree. Base `Xenial` image is in `/POCKET/SBC-IMG-BUILDER/ODROID`.  

**`minified-dist-image.sh`**

Make iso image with ripped off bootloader from official image `ubuntu64-16.04lts-mate-odroid-c2-20170106.img.xz`.  

## Development

**`minified-devel-filetree.sh`**

Development file tree. This will include more packages Base `Xenial` image is in `/POCKET/LINUX-BUILDER/BUILDER`.   

- OpenSSH server, Sudo, Build-essential, Python, software-common, Documents

**`minified-devel-image.sh`**

Make iso image with ripped off bootloader from official image `ubuntu64-16.04lts-mate-odroid-c2-20170106.img.xz`.  

## References

**Odroid C2 Boot Image download**

- [Ubuntu 16.04 (v2.2)](http://odroid.com/dokuwiki/doku.php?id=en:c2_release_linux_ubuntu)
- [Korea Mirror](http://dn.odroid.com/S905/Ubuntu/)
- [Flashing HOWTO](http://odroid.com/dokuwiki/doku.php?id=en:odroid_flashing_tools)


**Capture Bootloader from Downloaded `.img` file w/o baking**

**!!!Do this as baked image autoresize partitions when booted!!!**

We can further automate this process for CI.

1. Check checksum/ `file`/ `fdisk` to make sure it is intact
  
  ```sh
  $ file
  
  ubuntu64-16.04lts-mate-odroid-c2-20170106.img: DOS/MBR boot sector; partition 1 : ID=0xc, start-CHS (0x1,0,1), end-CHS (0x80,63,32), startsector 2048, 262144 sectors; partition 2 : ID=0x83, start-CHS (0x81,0,1), end-CHS (0x3ff,63,32), startsector 264192, 11059200 sectors
  ```

  ```sh
  $ fdisk -l ubuntu64-16.04lts-mate-odroid-c2-20170106.img
  
  Disk ubuntu64-16.04lts-mate-odroid-c2-20170106.img: 5.4 GiB, 5797576704 bytes, 11323392 sectors
  Units: sectors of 1 * 512 = 512 bytes
  Sector size (logical/physical): 512 bytes / 512 bytes
  I/O size (minimum/optimal): 512 bytes / 512 bytes
  Disklabel type: dos
  Disk identifier: 0xd3630000
  
  Device                                         Boot  Start      End  Sectors  Size Id Type
  ubuntu64-16.04lts-mate-odroid-c2-20170106.img1        2048   264191   262144  128M  c W95 FAT32 (LBA)
  ubuntu64-16.04lts-mate-odroid-c2-20170106.img2      264192 11323391 11059200  5.3G 83 Linux
  ```  
2. Take bootloader from image

  ```sh  
  # extract the boot sector
  dd if=./ubuntu64-16.04lts-mate-odroid-c2-20170106.img of="./BOOTLOADER-C2-3.14.79-102-20170125.img" bs=512 count=264192
  ```
3. Mount root `/` partition, not the bootloader. Since we need to scoot 264192 sectors ahead, and each sector is 512 bytes long, we need to use an offset of `$((264192 * 512))` bytes

  ```sh
  $ mount -o ro,loop,offset=$((264192 * 512)) ubuntu64-16.04lts-mate-odroid-c2-20170106.img /mnt
  ```
4. Capture vmLinuz `/boot` 

  ```sh
  tar ./BOOTDIR-C2-3.14.79-20170125.tar.gz /mnt/boot/
  ```
5. Capture firmware

  ```sh
  tar ./odroid-firmware-3.14.79-102.tar.gz /mnt/lib/firmware/3.14.79-102/
  ```
6. Capture modules

  ```sh  
  tar ./odroid-modules-3.14.79-102.tar.gz /mnt/lib/modules/3.14.79-102/
  ```
7. Capture **`/etc/fstab`** to mount disk properly.  
8. Capture kernel config (This need to be done with actual boot. Take what's available in `/boot/`)

> Reference

- <https://major.io/2010/12/14/mounting-a-raw-partition-file-made-with-dd-or-dd_rescue-in-linux/>

### Capture Bootloader from Baked SD Card

1. Get Clean Boot
  > Take bootloader from booted disk

  ```sh
  #remove any older files from /boot
  
  # mount mmcblk0p1 to remove OSX residue
  mount /dev/mmcblk0p1 /mnt
  rm -rf /mnt/.Spotlight-V100/ /mnt/.Trashes/ /mnt/._.Trashes /mnt/.fseventsd/
  umount /mnt
  
  # extract the boot sector
  dd if=/dev/mmcblk0 of="./BOOTLOADER-C2-$(uname -r)-20170125.img" bs=512 count=264192
  ```
2. Capture vmlinuz (from this point onward, we can do this from mounted filesystem (either SD Card or img mount)

  ```sh
  tar ./BOOTDIR-C2-$(uname -r)-20170125.tar.gz /boot/
  ```    
3. Capture firmware

  ```sh
  tar ./odroid-firmware-3.14.79-102.tar.gz /lib/firmware/3.14.79-102/
  ```
4. Capture modules

  ```sh  
  tar ./odroid-modules-3.14.79-102.tar.gz /lib/modules/3.14.79-102/
  ```
5. Capture config

  ```sh
  cp /proc/config.gz .
  ```

### First Boot setup (original odroid)

**`/etc/rc.local`**

```sh
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

if [ -f /aafirstboot ]; then /aafirstboot start ; fi

exit 0
```