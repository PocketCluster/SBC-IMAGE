# Raspberry PI 2/3 Image Builder

### `build-setting.sh`  

Build setting such as distro, directory, version & etc.   

### `build-dist-filetree.sh`  

Distribution file tree. Base `Xenial` image is in `/POCKET/UBUNTU-BUILDER/BUILDER`.  

### `build-devel-filetree.sh`  

Development file tree. This will include more packages. Base `Xenial` image is in `/POCKET/LINUX-BUILDER/BUILDER`.   

### `make-iso-image.sh`  

Make iso image.  

### `CONFIG_VXLAN` option

For this option, please update rpi-firmware at least to `4.4.22-v7+`. or

```sh
rpi-update d26c39bd353eb0ebbc7db3546277083eac4aa3bd
```

> References

- [pre-compiled binaries of the current Raspberry Pi kernel and modules](https://github.com/raspberrypi/firmware)
- [Firmware files for the Raspberry Pi](https://github.com/Hexxeh/rpi-firmware)
- [An easier way to update the firmware of your Raspberry Pi](https://github.com/Hexxeh/rpi-update)
- <https://github.com/Evilpaul/RPi-config>