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