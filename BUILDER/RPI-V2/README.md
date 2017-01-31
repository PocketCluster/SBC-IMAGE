# Raspberry PI 2/3 Image Builder V2 (ARMv7)

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