# Synopsis
This How-To describes a way to built and install Ubuntu 14.04 from scratch on the ARMv7 based (Freescale imx.6) utilite computer.

# Before you start

## Get a serial connection to the utilite computer
The utilite has two serial connectors, one at the front (`/dev/ttymxc3`) and one at the rear side (`/dev/ttymxc1`).  The one at the front (`/dev/ttymxc3`) is the default console for the firmware (U-Boot), kernel messages und the Linux environment.  I strongly recommend having a serial connection in place; otherwise you cannot interact with the firmware or see what happed when something went wrong. You need a null modem cable (and a serial to USB converter if you computers doesn't have a serial connector).  I’m using `minicom` (Linux) and `putty` (Windows) as terminal emulators when I connect to a serial console. You may read these links als well
* [Serial console connection with putty](http://www.utilite-computer.com/wiki/index.php/Utilite:_Android:_Serial_console_connection)
* [How-to use the serial connection](http://www.utilite-computer.com/forum/viewtopic.php?p=6766&sid=13f54968083de0f1fef9dbb0cfc78b8d#p6766)

## Have an ARMv7 build environment
This How-To assumes, that you are not cross compiling. So you need a viable Linux environment on the ARMv7 platform for building Ubuntu 14.04 and compiling the linux kernel. This environment doesn’t need to be an utilite, you may take any other ARMv7 based device as well. I used the official Ubuntu release (12.04) from utilite on the utilite pro ([Installation Guide](http://www.utilite-computer.com/wiki/index.php/Utilite_Linux_Installation_and_Update)). You will need the debootstrap package installed and a working compiler toolchain as well.

## Update the U-Boot firmware to the latest release (optional)
The latest U-Boot firmware ([Installation Guide](http://www.utilite-computer.com/wiki/index.php/U-Boot_Update)) offers some advantages, like booting from USB. If you don’t have an internal SSD, you will love the opportunity to boot from a different device then uSD. When you update the firmware, you should consider to update the U-Boot environment as well ([Forum Post](http://www.utilite-computer.com/forum/viewtopic.php?p=7696&sid=149c42efe44f08f45f21034196aa7dda#p7696)). You should get familiar with the basic U-Boot commands, in order to boot a different kernel or from a non-default device (boot from SSD, even when uSD is present at boot time).  

## Have a boot media
You need of cause a boot media on which you put the Ubuntu 14.04. If you update the U-Boot firmware and environment, this could be any USB storage device, otherwise you need a uSD Card (minimum capacity 4GB, I recommend class 10 or better).   

# Building the Ubuntu 14.04 environment (userland)

## Step 1: Download and unpack the userland
Having the environment in place, you can build the Ubuntu userland issuing the following commands (as root). 

    mkdir ./rootfs
    debootstrap --foreign --include=vim,dialog,apt --variant=minbase --arch=armhf trusty rootfs http://ports.ubuntu.com/

This will take some time, debootstrap will download an install the packages required for the minimal Ubuntu installation inside the target directory (`./rootfs`).  If you prefer another text editor like `nano`, you may append this package to the `–include=…` command line parameter.

## Step 2:  Configure the new userland from inside
The next step requires a `chroot` into the new Userland:

    mount -o bind /dev ./rootfs/dev
    mount -o bind /dev/pts ./rootfs/dev/pts
    mount -t sysfs /sys ./rootfs/sys
    mount -t proc /proc ./rootfs/proc
    cp /proc/mounts ./rootfs/etc/mtab
    chroot ./rootfs

Now you finish the installation:

    /debootstrap/debootstrap --second-stage
    localedef -i en_GB -c -f UTF-8 en_GB.UTF-8
    localedef -i de_DE -c -f UTF-8 de_DE.UTF-8
    dpkg-reconfigure locales
    dpkg-reconfigure tzdata
    echo utilite > /etc/hostname
    echo "127.0.0.1       localhost" >> /etc/hosts

Before you are able to install additional Ubuntu packages you need to modify `/etc/apt/sources.list` like this (you are still inside the new environment):

    deb http://ports.ubuntu.com/ trusty main restricted universe multiverse
    deb http://ports.ubuntu.com/ trusty-security main restricted universe multiverse
    deb http://ports.ubuntu.com/ trusty-updates main restricted universe multiverse
    deb http://ports.ubuntu.com/ trusty-backports main restricted universe multiverse

You may want to add some entries to the `/etc/fstab` (boot partition, swap space), but this could also be done when you have booted into the new environment.

You may also want to modify `/etc/network/interfaces` in order to have the network interfaces up and running, a sample configuration is here:

    # interfaces(5) file used by ifup(8) and ifdown(8)
    auto lo eth0 
    iface lo inet loopback
    iface eth0 inet dhcp
    iface eth1 inet dhcp
    #hwaddress ether 00:01:c0:13:fb:ef
    iface mlan0 inet dhcp

You will need to set the mac address of the `igb` interface (`eth1`), if you plan to boot a standard mainline Linux kernel built from source. The following command will give you the mac address of your `igb` interface:

    dd if=/sys/bus/i2c/devices/0-0050/eeprom bs=1 count=6 skip=4 2>/dev/null | od -A "n" -t x1


Essential is the modification/creation of `/etc/init/ttymxc3.conf` otherwise you won’t have a login shell on the serial console:

    # ttymxc3 - getty
    #
    # This service maintains a getty on ttymxc3
    
    description	"Get a getty on ttymxc3"

    start on runlevel [2345]
    stop on runlevel [016]
    
    respawn
    
    exec /sbin/getty -L 115200 ttymxc3
    #exec /sbin/getty -l /usr/bin/autologin -n 115200 ttymxc3 

Now it’s time to create additional user accounts:

    adduser <user>
    usermod -aG adm,cdrom,sudo,plugdev <user>

Before you start to install additional Ubuntu packages, you need to mock the `/sbin/init` environment (due to the `chroot`).

    dpkg-divert --local --rename --add /sbin/initctl
    ln -s /bin/true /sbin/initctl

Now, you may install additional packages (whatever you consider as essential):

    apt-get install aptitude make gcc bc lzop ssh man sudo ntp ntpdate usbutils pciutils less lsof most sysfsutils u-boot-tools linux-firmware linux-firmware-nonfree isc-dhcp-client net-tools

Remove the  mock:

    rm /sbin/initctl
    dpkg-divert --local --rename --remove /sbin/initctl

Exit the chroot shell:

    exit 
 
Here you are, the Ubuntu userland should be fine now! The userland should work on other ARMv7 platforms as well (I use this one for the CuBox-i).
You may enter it again via chroot, as often as you need to (e.g. install the kernel image), but don’t forget the bindmounts before entering. 

# Installing the Linux kernel image and kernel modules
You may choose between different options:
* Custom Linux kernel provided by utilite and freescale (3.0.35-cm-fx6) ([Link](http://www.utilite-computer.com/wiki/index.php/Utilite_Linux_Installation_and_Update)), either as package ([Link](http://utilite-computer.com/download/utilite/kernel/linux-image-imx6_3.0.35-cm-fx6-6.1_all.deb)), or as custom build from the source ([Link](http://www.utilite-computer.com/wiki/index.php/Utilite_Linux_Kernel))
* Development custom Linux Kernel provided by utilite (3.10.17) either as package or as custom build from the source 
([Link](http://www.compulab.co.il/utilite-computer/wiki/index.php/Utilite_Linux_Kernel_3.10))
* Development custom Linux Kernel provided by freescale/SolidRun (3.14.y) as custom build from the source ([Link](https://github.com/SolidRun/linux-fslc))

  
## Installation via packages
Utilite provides packages/archives and scripts for installing the linux kernel image and the kernel modules. You may install it inside the chroot environment.

The kernel image resides in the /boot directory, the modules inside /lib/modules/<kernel-version> .

## Installation from source
Building the linux kernel from the source, differs from version to version and requires a working compiler toolchain. You may want to update to the latest gcc version (4.9.2) in order to compile recent kernels:

    sudo apt-get install software-properties-common python-software-properties
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test
    sudo apt-get update
    sudo apt-get install gcc-4.9
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 60 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 40 --slave /usr/bin/g++ g++ /usr/bin/g++-4.9
    sudo update-alternatives --config gcc

`sudo update-alternatives --config gcc` will give you the choice which compiler version should be used when issuing `gcc`

### 3.0.35-cm-fx6 ([Link](http://www.utilite-computer.com/wiki/index.php/Utilite_Linux_Kernel))
The default kernel configuration will yield a running kernel, so this is a good starting point for further experiments. The following steps will help you to compile the kernel:

    git clone git://gitorious.org/utilite/utilite.git

will download the latests source files into a directory called `utilite`. To update the source files you've downloaded so time ago, just enter          

    git pull origin
inside the `utilite` directory.

    make utilite_defconfig
will create utilite tailored kernel configuration file (`.config`).

    make menuconfig
will give you the chance to add / remove specific configuration options (e.g. iptables support). There is no version history, when you are changing options. If you want to revert specific changes, you may consider to use `ci` and `co` from the `rcs` package (especially `ci -l <file>`)([Link](http://oreilly.com/perl/excerpts/system-admin-with-perl/five-minute-rcs-tutorial.html)). You can pick the config I've used to compile this kernel [here](https://www.dropbox.com/sh/1ln93hvod4tki5s/AABMO2SGv8PJ2dTaQRV4DmROa?dl=0).

    make -j 4 clean                                                          
    make -j 4 uImage modules                                                 
    make modules_install                  
    cp arch/arm/boot/uImage /boot/uImage-cm-fx6_3.0.35-6.1
will compile and install the kernel and the kernel modules. If you want to install the kernel modules to a different location, let's say `/mnt/lib/modules/...` just specify the base directory (`/mnt`) within the environment variable `INSTALL_MOD_PATH`:

    INSTALL_MOD_PATH=/mnt/ make modules_install

### 3.10.17 ([Link](http://www.compulab.co.il/utilite-computer/wiki/index.php/Utilite_Linux_Kernel_3.10))
This version is still under development, I've integrated docker support in my fork:
```
git clone -b 'utilite/devel' --single-branch https://github.com/umiddelb/linux-kernel
cd linux-kernel
make cm_fx6_defconfig
make -j 4 zImage modules
sudo make modules_install
sudo make firmware_install
sudo make headers_install
make imx6q-sbc-fx6m.dtb imx6dl-sbc-fx6m.dtb
# Please uncomment one the following lines below
#  imx6q-sbc-fx6m.dtb: is used by the Utilite Pro
#  imx6dl-sbc-fx6m.dtb: is used by the Utilite Standard 
#cat arch/arm/boot/zImage arch/arm/boot/dts/imx6q-sbc-fx6m.dtb > /tmp/zImage-cm-fx6
#cat arch/arm/boot/zImage arch/arm/boot/dts/imx6dl-sbc-fx6m.dtb > /tmp/zImage-cm-fx6
sudo mkimage -A arm -O linux -T kernel -C none -a 0x10008000 -e 0x10008000 -n 3.10.17-cm-fx6-1-beta4-aufs -d /tmp/zImage-cm-fx6 /boot/uImage-cm-fx6
rm -f /tmp/zImage-cm-fx6
````

### (Exhibit) Download a minimal rootfs (userland only)
The [Ubuntu Core](https://wiki.ubuntu.com/Core) project offers a minimal root fs for [download](http://cdimage.ubuntu.com/ubuntu-core/releases/14.04/release/) if you feel more comfortable with an official download source. After extracting the archive into `./rootfs` you may continue [here] (https://github.com/umiddelb/armhf/wiki/Installing-Ubuntu-14.04-on-the-utilite-computer-from-scatch#step-2--configure-the-new-userland-from-inside), skipping the `/debootstrap/debootstrap --second-stage` step. 

# Preparing your boot media
## Create a tar.bz2 archive from your Ubuntu installation 

    cd ./rootfs
    tar --numeric-owner –cpjf …/trusty.tar.bz2 *

## Copy the archive to a system from which you can prepare the uSD / USB media
If you have an utilite with internal SSD, you can compose the Ubuntu installation on the SSD and prepare the uSD on the same device. In the other case, I recommend to use another Linux System (i386, x64 or ARM doesn’t matter) on which you prepare the uSD card. If you have updated the U-Boot firmware und environment, you my use an USB storage device instead of uSD. 

## Partition the boot media
Older versions of the U-Boot firmware require a `vfat` partition to load the kernel image from. So you tend to have small `vfat` partition holding the kernel images only and a large `ext4` partition for the rest. On the ARM platform, the first partition usually starts at sector 2048, reserving enough space if you want to put the U-Boot firmware on the uSD afterwards. On the PC platform, you may check this, when you create the partitioning scheme.

    echo -e "n\np\n1\n\n+100M\na\n1\nt\nc\nn\np\n2\n\n\nw\neof\n" | fdisk <bootmedia>

If you have updated the U-Boot firmware und environment, you don’t need have two separate partitions anymore. Just create one large `ext4` partition. 

## Create the file systems
Flash memory based storage devices will have a longer lifetime if you reduce the amount of sustaining write requests. For this reason, it’s recommended to create the `ext4` filesystem without the transaction log journal:

    mkfs.vfat -n boot <bootmedia>1
    mkfs.ext4 -O ^has_journal -E stride=2,stripe-width=1024 -b 4096 -L rootfs <bootmedia>2

## Mount the filesystems in the correct order

    mount /dev/<bootmedia>2 /mnt
    mkdir /mnt/boot
    mount /dev/<bootmedia>1 /mnt/boot

## Extract the archive on the boot media

    tar --numeric-owner –xpjf …/trusty.tar.bz2 –C /mnt
    sync

You may consider to copy the archive file itself to the boot media, if there is enough space. This will simplify the installation on the SSD, when you have booted successfully from the uSD. 

## Choose the default kernel image to be loaded by default
Just copy your preferred kernel image file to `/boot/uImage-cm-fx6`. The U-Boot firmware on the utilite tries to load by default a file called `uImage-cm-fx6` from the root of the first partition (first uSD, then SSD). If there is no such file, the firmware will change into interactive mode on the serial line waiting for further commands. You may change this behaviour modifying the U-boot Environment variable `kernel`. 
## Unmount the filesystems and remove the boot media

    sync
    umount /dev/<bootmedia>1 /mnt/boot
    umount /dev/<bootmedia>2 /mnt

Now it should be safe to remove the boot media.

# Boot the utilite from uSD
If everything runs fine, you may want to install the archive to the internal SSD as well.

Have fun. Please send any remarks, comments and improvements to uli@middelberg.de

# To be continued ... 
* Set up cypto
* Set up [WiFi](https://github.com/umiddelb/armhf/wiki/Setting-up-hostapd-on-the-utilite)
* Set up [docker](https://github.com/umiddelb/armhf/wiki/Installing,-running,-using-docker-on-armhf-(ARMv7)-devices)
