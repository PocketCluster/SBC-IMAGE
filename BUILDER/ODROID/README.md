# Odroid-C2 Image Builder

### `build-setting.sh`  

Build setting such as distro, directory, version & etc.   

### `build-arm64-base.sh`  

Really basic `arm64` file tree builder.  

### `build-dist-filetree.sh`  

Distribution file tree. Base `Xenial` image is in `/POCKET/UBUNTU-BUILDER/XENIAL-IMAGE`.  

### `build-devel-filetree.sh`  

Development file tree. This will include more packages. Base `Xenial` image is in `/POCKET/LINUX-BUILDER/XENIAL-IMAGE`.   

### `make-ripped-image.sh`  

Make iso image with ripped off bootloader from official image `ubuntu64-16.04lts-mate-odroid-c2-20160226.img.xz`.  

### `make-uboot-image.sh`  

Make iso image following the official guide.  
