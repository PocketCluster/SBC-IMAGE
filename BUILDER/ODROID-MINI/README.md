# Odroid-C2 Minified Image Builder

### `minified-settings.sh`  

Build setting such as distro, directory, version & etc.   

### `minified-dist-filetree.sh`  

Distribution file tree. Base `Xenial` image is in `/POCKET/UBUNTU-BUILDER/BUILDER`.  

### `minified-dist-image.sh`  

Make iso image with ripped off bootloader from official image `ubuntu64-16.04lts-mate-odroid-c2-20160226.img.xz`.  

### `minified-devel-filetree.sh`  

Development file tree. This will include more packages Base `Xenial` image is in `/POCKET/LINUX-BUILDER/BUILDER`.   

- OpenSSH server, Sudo, Build-essential, Python, software-common, Documents

### `minified-devel-image.sh`  

Make iso image with ripped off bootloader from official image `ubuntu64-16.04lts-mate-odroid-c2-20160226.img.xz`.  

### Odroid C2 Boot Image download

- [Ubuntu 16.04 (v2.2)](http://odroid.com/dokuwiki/doku.php?id=en:c2_release_linux_ubuntu)
- [Korea Mirror](http://dn.odroid.com/S905/Ubuntu/)
- [Flashing HOWTO](http://odroid.com/dokuwiki/doku.php?id=en:odroid_flashing_tools)


### Capture Bootloader

1. Get Clean Boot

  > **Take bootloader from image. Do this as booted image autoresize partitions**
  
  ```sh  
  # extract the boot sector
  dd if=./ubuntu64-16.04lts-mate-odroid-c2-20170106.img of="./BOOTLOADER-C2-3.14.79-102-20170125.img" bs=512 count=264192
  ```

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