This tutorial covers some aspects about compiling your own Linux kernel for your ARM device. Most Linux distributions for the PC/x86 platform maintain a Linux kernel which supports a broad range of hardware devices, so it has become very unlikely to compile your own kernel from source. For the ARM platform the Linux kernel is provided by the board or system on chip (SoC) manufacturer. In some cases these kernels include a minimal set of features and device drivers only.

Beside of this you may want to include a specific feature set which is provided as a patch set to the kernel sources only, like [enhanced security](https://grsecurity.net/) or [real-time capabilities](https://rt.wiki.kernel.org/index.php/Main_Page).

Some use cases impose special requirements, e.g. you prefer to switch off loadable kernel modules support in security relevant environments and build a monolithic kernel instead. Or you have to cope with restricted resources and need to build a very tiny kernel image.

Recent ARM devices have become quite powerful, so I prefer to compile the kernel on the target device directly instead of cross compiling (which adds some extra level of complexity).

The people from the ODROID Magazine kindly published this article in their [2016-01 issue](http://magazine.odroid.com/201601).
 
# Kernel components
The Linux kernel consists of the following components:
 
- Kernel image 
  - 32 bit platform: `<boot-partition>/zImage` or `<boot-partition>/uImage`, depending on your u-boot's capabilities and configuration
  - 64 bit platform: `<boot-partition>/Image`
- Device tree binary, a low level device description, specific to your device (`<boot-partition>/<board>.dtb`)
- Kernel modules (`/lib/modules/<kernel-version>/*`)
- Device firmware (`/lib/firmware/*`)
- Kernel C header files (`/usr/include/linux`)

Theses components are build out of the kernel sources with the help of the `make` utility. Usually the kernel image and the device tree binary are loaded from a small vfat boot partition (mounted as `/boot` or `/media/boot`), whereas the rest resides in the root file system.

# Prepare your build environment

Beside of `make`, several other utilities are needed to compile the Linux kernel,
e.g. for Ubuntu you need to install the following packages

```bash
sudo apt-get -y install bc curl gcc git libncurses5-dev lzop make u-boot-tools
```
 
## Make gcc-5 your default compiler

Most Linux distributions are updating their default compiler to gcc version 5 as time of this writing. If your distribution still uses gcc version 4.8 as default you should consider to gcc version 5, e.g. for Ubuntu 14.04:

```bash
apt-get -y install python-software-properties;
add-apt-repository -y ppa:ubuntu-toolchain-r/test;
apt-get update
apt-get -y install gcc-5 g++-5
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 50
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 50
```

The command `update-alternatives` helps you to define the default command to be executed if different versions of the same command are installed at the same time. 

You can check the gcc version with
```bash
gcc --version
```

## Become familiar with u-boot

Compiling a custom kernel always comes with the risk that your new kernel won't boot for whatever reason. Some knowledge about the ARM boot loader `u-boot` helps you to boot a well known kernel image and to get your ARM device up again. I recommend to define an u-boot macro which will load and boot a test kernel before overwriting the existing default kernel. You can find more information about u-boot [here](https://github.com/umiddelb/armhf/wiki/Get-more-out-of-%22Das-U-Boot%22).

# Download kernel sources

The site [www.kernel.org](http://www.kernel.org) offers the mainline Linux kernel sources for download, e.g.:

```bash
curl -sSL https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.7.5.tar.xz | unxz | tar -xvf -
```

You can get the most recent releases there, but only a few ARM devices are able to boot a mainline kernel out of the box, and even if they have successfully started Linux, it is very likely that some devices still lack of support, e.g. graphics acceleration. 

To get a kernel with extensive support for your ARM board, you need to fetch the kernel sources provided by the board vendor. In most cases these sources contain additional patches for a kernel version with long term support. Today many vendors use [github](https://github.com/) to provide and manage their specific kernel sources, which makes it very easy to add back own contributions. 
Usually the vendors organize the kernel sources for particular boards in designated github branches:

|   Board | Linux 3.8 | Linux 3.10 | Linux 3.14 | Linux 4.2 | Linux 4.8 |
| -------:|----------:|-----------:|-----------:|----------:|----------:|----------:|
| Utilite |-|[utilite/devel](https://github.com/utilite-computer/linux-kernel) | [3.14-1.0.x-mx6-sr](https://github.com/umiddelb/linux-fslc)|-|[mainline](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.8.tar.xz)|
| CuBox-i |-|[linux-linaro-lsk-3.10.42-mx6](https://github.com/SolidRun/linux-imx6-3.14)| [3.14-1.0.x-mx6-sr](https://github.com/SolidRun/linux-fslc.git)|[mainline](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.2.8.tar.xz)|[mainline](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.8.tar.xz)|
| RaspberryPi 1/2|[rpi-3.8.y](https://github.com/raspberrypi/linux)|[rpi-3.10.y](https://github.com/raspberrypi/linux)|[rpi-3.14.y](https://github.com/raspberrypi/linux)|[rpi-4.2.y](https://github.com/raspberrypi/linux)|[rpi-4.8.y](https://github.com/raspberrypi/linux)|
|ODROID C1(+)|-|[odroidc-3.10.y](https://github.com/hardkernel/linux)|-|-|[(mainline)](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.8.tar.xz)|
|ODROID C2|-|-|[odroidc2-3.14.y](https://github.com/hardkernel/linux)|-|[(mainline)](https://github.com/xdarklight/linux/tree/meson-gxbb-integration-4.8-20160923)
|ODROID X2|[odroid-3.8.y](https://github.com/hardkernel/linux)|-|-|-|[odroid-4.8.y](https://github.com/tobiasjakobi/linux-odroid-public/tree/odroid-4.8.y)
|ODROID U3|[odroid-3.8.y](https://github.com/hardkernel/linux)|-|-|-|-|
|ODROID XU3|-|[odroidxu3-3.10.y](https://github.com/hardkernel/linux)|-|-|-|
|ODROID XU4|-|[odroidxu3-3.10.y](https://github.com/hardkernel/linux)|-|[odroidxu4-v4.2](https://github.com/tobetter/linux)|[mainline](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.8.tar.xz)|
|PINE64|-|[pine64-hacks-1.2](https://github.com/longsleep/linux-pine64)|-|-|[(mainline)](https://github.com/apritzel/linux/tree/a64-v5)|


The `git clone` command creates a local copy of the origin repository by  

```bash
git clone --depth 1 --single-branch -b <branch> <URL to the repository>
```

This local copy contains only the branch specified by `-b` and no information about prior commits (--depth 1) which will reduce the download size to a certain extend. For example 

```bash
git clone --depth 1 --single-branch -b odroidc-3.10.y https://github.com/hardkernel/linux
```

downloads the kernel source code for the ODROID C1 into the directory `./linux`.

# Build your custom kernel

It's time to start building your own kernel now. After downloading and extracting the kernel sources you start with creating the configuration file called `.config`. This text file contains the relevant parameters for your kernel, one line per kernel option.

```bash
cd linux
make <default_config>
less .config
```

You can find the default configuration available for your ARM device in the directory `./arch/arm/configs/`. These are for the boards mentioned above:

|   Device     | default configuration   |
|-------------:|------------------------------:|
|Utilite       |`cm_fx6_defconfig`             |
|CuBox-i       |`imx_v7_cbi_hb_defconfig`      |
|RaspberryPi 1 |`bcmrpi_defconfig`             |
|RaspberryPi 2 |`bcm2709_defconfig`            |
|ODROID C1(+)  |`odroidc_defconfig`            |
|ODROID C2     |`odroidc2_defconfig`           |
|ODROID X2     |`exynos_defconfig`             |
|ODROID U3     |`odroidu_defconfig`            |
|ODROID XU3    |`odroidxu3_defconfig`          |
|ODROID XU4    |`odroidxu4_defconfig`          |
|PINE64        |`sun50iw1p1smp_linux_defconfig`|

Once the kernel configuration `.config` has been created you can modify it either  with a text editor of your choice or by starting

```bash
make menuconfig
```

![sreenshot of make menuconfig](https://github.com/umiddelb/armhf/blob/master/img/make-menuconfig.png)

and changing the kernel configuration interactively.

If enabled as a configuration option you can read the current kernel configuration of a running kernel by: 

```bash
cat /proc/config.gz | gunzip | less
```

When you are done with the kernel configuration you may create a new default configuration by starting:
  
```bash
make savedefconfig
```

This command creates a file called `defconfig` out of `.config` which contains only the changes with respect to the global kernel configuration defaults and reduces the file size to 15%-20% of the original `.config`. 

The next step is to build the kernel image (`Image`, `uImage` or `zImage`), the device tree binary and the kernel modules. This is the most time consuming task and even with parallel execution (`make -j 4`) it takes about one hour the compile the C1 Linux on the C1 itself (and 20 minutes on the XU4):

```bash
make -j 4 [u|z]Image dtbs modules
```

# Install your custom kernel
As mentioned earlier, you might want to test your new kernel before replacing your existing one. This step requires some knowledge about u-boot and the particular u-boot configuration for your board. You need to define an u-boot macro which boots your custom kernel instead of the system default. 

When you're done with testing, you can install the new kernel as the system default.    

```bash
sudo cp ./arch/arm/boot/*(u)*(z)Image ./arch/arm/boot/dts/*.dtb <boot-partition>
sudo make modules_install
sudo make firmware_install
sudo make headers_install INSTALL_HDR_PATH=/usr
```

The kernel image and the device tree binary are installed in the boot partition whereas the kernel modules, the device firmware and the C header files are copied to the root file system. If you are running different Linux installations on different partitions of your eMMC or SD storage device with the same kernel image you need to install the kernel modules (e.g. by `sudo make modules_install INSTALL_MOD_PATH=...`), the device firmware (`sudo make firmware_install INSTALL_FW_PATH=...`) and the C header files on each of this partitions. You can get a list of all make targets and parameters by typing `make help`.    

# Update you initramfs/initrd image
Some configurations require a ramdisk image (`<boot-partition>/uInitrd`) to be loaded during startup before entering the 'real' root file system. This ramdisk image contains some startup scripts and the kernel modules for a particular kernel. The command `update-initramfs` creates or updates this image. Please make sure that the kernel modules don't contain debug information (remove `CONFIG_DEBUG_INFO=y` from your kernel configuration), otherwise the ramdisk image size will grow significantly and might break space limitations imposed by the boot loader. 

Instead of building the kernel modules again you can remove the debug information by executing:

```
cd /lib/modules/<kernel version>
sudo find . -type f -name '*.ko' | sudo xargs -n 1 objcopy --strip-unneeded       
```

The image created by `update-initramfs` has to be translated into an u-boot loadable image via `mkimage` and to be copied to the boot partition, see the examples section for further details. 

# How-To contribute
GitHub makes it very easy to manage you own fork of the kernel sources and to suggest changes to the upstream repository. This [guide here](https://guides.github.com/activities/forking/) is a good starting point for inexperienced GitHub Users.   
 
# Examples

## [ODROID-C1(+)](http://odroid.com/dokuwiki/doku.php?id=en:c1_ubuntu_release_note_v1.2)
```bash
$ git clone --depth 1 --single-branch -b odroidc-3.10.y https://github.com/hardkernel/linux
$ cd linux
$ make odroidc_defconfig
$ make -j 4 uImage dtbs modules
$ sudo cp arch/arm/boot/uImage arch/arm/boot/dts/*.dtb /media/boot
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mkimage -A arm -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd.img-${kver} -d initrd.img-${kver} uInitrd-${kver}
$ sudo cp uInitrd-${kver} /media/boot/uInitrd
```

## [ODROID-C1 mainline (experimental!)](http://linux-meson.com/doku.php)
```bash
$ curl -sSL https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.8.tar.xz | unxz | tar -xvf -
$ cd linux
$ make multi_v7_defconfig
$ make -j 4 LOADADDR=0x00208000 uImage dtbs modules
$ sudo cp arch/arm/boot/uImage arch/arm/boot/dts/*.dtb /media/boot
$ sudo make modules_install
$ sudo make firmware_install
```

## [ODROID-C2](http://odroid.com/dokuwiki/doku.php?id=en:c2_ubuntu_release_note_v1.0)
```bash
$ git clone --depth 1 --single-branch -b odroidc2-3.14.y https://github.com/hardkernel/linux
$ cd linux
$ make odroidc2_defconfig
$ make -j 4 Image dtbs modules
$ sudo cp arch/arm64/boot/Image arch/arm64/boot/dts/meson64_odroidc2.dtb /media/boot
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mkimage -A arm64 -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd.img-${kver} -d initrd.img-${kver} uInitrd-${kver}
$ sudo cp uInitrd-${kver} /media/boot/uInitrd
```

## [ODROID-C2 mainline (experimental!)](http://linux-meson.com/doku.php)
```bash
git clone --depth 1 --single-branch -b c2 https://github.com/ioft/linux
img="Image"
arch="arm64"
dtbs="dtbs"
make odroidc2_defconfig
make clean
make -j 4 ${img} modules ${dtbs}
kver=`make kernelrelease`
dest="/boot/kernel.d/linux-${kver}"
sudo rm -rf ${dest}
sudo mkdir -p ${dest}
sudo rm -rf /boot/kernel.d/test
sudo ln -s ${dest} /boot/kernel.d/test
sudo cp System.map arch/${arch}/boot/${img} arch/${arch}/boot/dts/amlogic/*.dtb ${dest}
sudo mkimage -A ${arch} -O linux -T kernel -C none -a 0x1080000 -e 0x1080000 -n ${kver} -d arch/${arch}/boot/${img} ${dest}/uImage
sudo cp .config ${dest}/config-${kver}
sudo make modules_install
sudo make firmware_install
sudo make headers_install INSTALL_HDR_PATH=/usr
cd /boot
sudo rm -f config-${kver}
sudo rm -f initrd.img-${kver}
sudo ln -s ${dest}/config-${kver} .
sudo update-initramfs -c -k ${kver}
sudo mkimage -A ${arch} -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd-${kver}.img -d initrd.img-${kver} uInitrd-${kver}
sudo mv initrd.img-${kver} ${dest}
sudo mv uInitrd-${kver} ${dest}/uInitrd
sudo rm config-${kver}
```

## [ODROID-X2](http://linux-exynos.org/wiki/Hardkernel_ODROID-X2)
See **kernel setup and build** in the Wiki for build instructions of both kernel and u-boot.

## [ODROID-U3](http://odroid.com/dokuwiki/doku.php?id=en:u3_building_kernel)
```bash
$ git clone --depth 1 --single-branch -b odroid-3.8.y https://github.com/hardkernel/linux
$ cd linux 
$ make odroidu_defconfig
$ make -j 4 zImage modules
$ sudo cp arch/arm/boot/zImage /media/boot
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mkimage -A arm -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd.img-${kver} -d initrd.img-${kver} uInitrd-${kver}
$ sudo cp uInitrd-${kver} /media/boot/uInitrd
```

## [ODROID-XU3](http://odroid.com/dokuwiki/doku.php?id=en:xu3_building_kernel)
```bash
$ git clone --depth 1 --single-branch -b odroidxu3-3.10.y https://github.com/hardkernel/linux
$ cd linux 
$ make odroidxu3_defconfig
$ make -j 8 zImage dtbs modules
$ sudo cp arch/arm/boot/zImage arch/arm/boot/dts/*.dtb /media/boot
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mkimage -A arm -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd.img-${kver} -d initrd.img-${kver} uInitrd-${kver}
$ sudo cp uInitrd-${kver} /media/boot/uInitrd
```

## [ODROID-XU4](http://odroid.com/dokuwiki/doku.php?id=en:xu4_building_kernel)
```bash
$ git clone --depth 1 --single-branch -b odroidxu4-v4.2 https://github.com/tobetter/linux
$ cd linux 
$ make odroidxu4_defconfig
$ make -j 8 zImage dtbs modules
$ sudo cp arch/arm/boot/zImage arch/arm/boot/dts/*.dtb /media/boot
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mkimage -A arm -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd.img-${kver} -d initrd.img-${kver} uInitrd-${kver}
$ sudo cp uInitrd-${kver} /media/boot/uInitrd
```

## ODROID-XU4 mainline
```bash
$ git clone --depth 1 --single-branch -b master https://github.com/ioft/linux/
$ cd linux  
$ make odroidxu4_defconfig
$ make -j 8 zImage dtbs modules
$ sudo cp arch/arm/boot/zImage arch/arm/boot/dts/*.dtb /media/boot
$ sudo cp .config /media/boot/config
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mkimage -A arm -O linux -T ramdisk -a 0x0 -e 0x0 -n initrd.img-${kver} -d initrd.img-${kver} uInitrd-${kver}
$ sudo cp uInitrd-${kver} /media/boot/uInitrd
```

## [PINE64 3.10 BSP kernel ](https://www.pine64.com/product) 
```
$ git clone --depth 1 --single-branch -b pine64-hacks-1.2 https://github.com/longsleep/linux-pine64
$ curl -sSL https://github.com/longsleep/build-pine64-image/raw/master/blobs/pine64.dts > linux-pine64/arch/arm64/boot/dts/sun50i-a64-pine64-plus.dts
$ cd linux-pine64
$ make sun50iw1p1smp_linux_defconfig
$ make -j 4 Image sun50i-a64-pine64-plus.dtb modules
$ sudo cp arch/arm64/boot/dts/sun50i-a64-pine64-plus.dtb arch/arm64/boot/Image /boot/pine64
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mv initrd.img-${kver} initrd.img
$ sudo mv config-${kver} /boot/pine64
```

## [PINE64 mainline kernel ](https://www.pine64.com/product) 
```
$ git clone --depth 1 --single-branch -b a64-v6-wip https://github.com/apritzel/linux
$ cd linux
$ make defconfig
$ make -j 4 Image modules dtbs
$ sudo cp arch/arm64/boot/dts/*.dtb arch/arm64/boot/Image /boot/pine64
$ sudo make modules_install
$ sudo make firmware_install
$ sudo make headers_install INSTALL_HDR_PATH=/usr
$ kver=`make kernelrelease`
$ sudo cp .config /boot/config-${kver}
$ cd /boot
$ sudo update-initramfs -c -k ${kver}
$ sudo mv initrd.img-${kver} initrd.img
$ sudo mv config-${kver} /boot/pine64
```

# Building a test kernel on ODROID boards 

- Copy to contents of `/media/boot` to a new directory on your boot partition e.g. `/media/boot/backup`.  
- If your test kernel has the same version as your productive one, you should define a naming extension (e.g. `CONFIG_LOCALVERSION="-dev"`) in the kernel configuration `.config` in order to prevent the current kernel modules to be overwritten.
- Copy the kernel image and the device tree binary to `/media/boot/test` instead of `/media/boot`
- If you don't have serial console access, you may choose to tweak the file `/media/boot/boot.ini`. You can modify the path for loading the kernel and the device tree binary, e.g. for the ODROID C1:

```
setenv prefix '/test/'
...
fatload mmc 0:1 0x21000000 ${prefix}uImage
fatload mmc 0:1 0x22000000 uInitrd
fatload mmc 0:1 0x21800000 ${prefix}meson8b_odroidc.dtb
...
```
If you want to switch back to your backup kernel image, you change the u-boot variable `prefix` to `/backup/`.

- If you have access to u-boot via serial console, you may define an u-boot macro, which loads the kernel image and the device tree binary from `/media/boot/test`, see [here](https://github.com/umiddelb/armhf/wiki/Get-more-out-of-%22Das-U-Boot%22#boot-an-alternative-kernel-image) for more details.

Please don't forget to run `make clean` before building a kernel again.