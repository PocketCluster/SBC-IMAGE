# Odroid-C2 Image Builder

### `build-setting.sh`  

Build setting such as distro, directory, version & etc.   

### `build-dist-filetree.sh`  

Distribution file tree. Base `Xenial` image is in `/POCKET/UBUNTU-BUILDER/BUILDER`.  

### `build-devel-filetree.sh`  

Development file tree. This will include more packages. Base `Xenial` image is in `/POCKET/LINUX-BUILDER/BUILDER`.   

### `make-ripped-image.sh`  

Make iso image with ripped off bootloader from official image `ubuntu64-16.04lts-mate-odroid-c2-20160226.img.xz`.  

### `make-uboot-image.sh`  

Make iso image following the official guide.  
