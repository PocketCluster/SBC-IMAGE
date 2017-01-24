# Odroid-C2 Minified Image Builder

Install qemu packages & enable platforms
  
```sh
apt-get -y install binfmt-support debootstrap f2fs-tools qemu-user-static rsync ubuntu-keyring wget whois

update-binfmts --enable qemu-arm
update-binfmts --enable qemu-aarch64
```

### `minified-settings.sh`  

Build setting such as distro, directory, version & etc.   

### `minified-dist-filetree.sh`  

Distribution file tree. Base `Xenial` image is in `/POCKET/UBUNTU-BUILDER/BUILDER`.  

### `minified-devel-filetree.sh`  

Development file tree. This will include more packages. Base `Xenial` image is in `/POCKET/LINUX-BUILDER/BUILDER`.   

### `minified-ripped-image.sh`  

Make iso image with ripped off bootloader from official image `ubuntu64-16.04lts-mate-odroid-c2-20160226.img.xz`.  
