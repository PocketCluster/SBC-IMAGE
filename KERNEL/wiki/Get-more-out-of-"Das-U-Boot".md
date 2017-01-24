# Synopsis
The majority of recent ARM based devices use "Das U-Boot" (u-boot) to load and start the Linux kernel. Many vendors focus on an end-user friendly u-boot configuration. If you need more flexibility, it is worth a deeper look into the u-boot internal structure

The people from the ODROID Magazine kindly published this artice in their [2015-11 issue](http://forum.odroid.com/viewtopic.php?f=7&t=17263). 

# What is u-boot?

U-boot is a boot loader similar to [lilo](http://lilo.alioth.debian.org/) or [grub](https://www.gnu.org/software/grub/), but is specifically designed for embedded devices. U-boot is maintained by [denx](http://www.denx.de/wiki/U-Boot/WebHome) and published under the GNU General Public License version 2 (GPL-2.0+). Compared to grub, u-boot doesn’t offer a high level of selfconfiguration or end-user friendliness, but it does offer a much smaller footprint. 

The most convenient way to interact with u-boot is via serial console. Many ARM devices offer serial access via USB, which makes it easy to manage console access. Just connect the serial console via USB to another Linux box,  and you have remote serial access to your ARM device. To do so, log in to your Linux box via ssh and open the serial connection via minicom(1):

    sudo minicom -b 115200 -D /dev/ttyUSB0

Press `^A z` to open the interactive help/configuration screen, press `^A x` to exit your minicom session. 

`minicom` isn't the only terminal emulator for serial access, screen(1) and picocom(8) are popular alternatives:

    sudo picocom -b 115200 /dev/ttyUSB0

Press `^A ^X` to exit your picocom session.

# The boot process

When a device gets powered on, it has to go through various initialization stages before you see the operating system login prompt or desktop.  

## Stage 1 (Secondary Program Loader / SPL)
The first stage of the boot process is the Secondary Program Loader (SPL).  This preliminary piece of code is responsible for board initialization, loading the u-boot binary (“secondary program”) and handling the control flow over to the u-boot main program.  It is device specific, and is often provided as a closed source binary blob by the SoC vendor.

The secondary program loader (SPL) and the u-boot binary reside in a special on-board flash memory region or on the first sectors of the uSD/eMMC card.  ODROID devices use microSD or eMMC modules for storing the SPL and u-boot binary. The individual disk regions are detailed in the disk layout and [partitioning section](https://github.com/umiddelb/armhf/wiki/Get-more-out-of-%22Das-U-Boot%22#disk-layout-and-partitioning) below.

## Stage 2 (u-boot)
At the second stage of the boot process, the u-boot main program is executed.  U-boot first looks for a custom environment stored at a reserved space on the microSD or eMMC module, or falls back to the compile-time default environment if needed.  At this time, you can interrupt the automatic boot process by pressing a key on your serial console, which starts an interactive u-boot shell.  The u-boot variable called `bootdelay` specifies the number of seconds to wait for a keypress before continuing automatic boot.

```
CPU : AMLogic S805
MEM : 1024MB (DDR3@792MHz)
BID : HKC13C0001
S/N : HKC1CC037EBCBFA4
0x0000009f
Loading U-boot...success.


U-boot-00000-geb22ea4-dirty(odroidc@eb22ea4b) (Jul 28 2015 - 22:16:46)

DRAM:  1 GiB
relocation Offset is: 2ff1c000
MMC:   eMMC: 0, SDCARD: 1
IR init is done!
vpu clk_level = 3
set vpu clk: 182150000Hz, readback: 182150000Hz(0x701)
mode = 6  vic = 4
set HDMI vic: 4
mode is: 6
viu chan = 1
config HPLL
config HPLL done
reconfig packet setting done
MMC read: dev # 0, block # 33984, count 12288 ... 12288 blocks read: OK
There is no valid bmp file at the given address
============================================================
Vendor: Man 450100 Snr 01172c20 Rev: 4.7 Prod: SDW16
            Type: Removable Hard Disk
            Capacity: 15028.0 MB = 14.6 GB (30777344 x 512)
------------------------------------------------------------
Partition     Start Sector     Num Sectors     Type
    1                 3072          524288       b
    2               527360        14680064      83
    3             15207424        15569920      83
============================================================
Net:   Meson_Ethernet
init suspend firmware done. (ret:0)
Hit Enter key to stop autoboot -- :  3 tstc enter

exit abortboot: 1
odroidc#
```

The automatic boot process executes a special u-boot macro called `bootcmd`, which loads and executes the following procedures:

1. (opt.) a custom u-boot environment: `uEnv.txt`
- (opt.) a precompiled u-boot macro: `boot.scr`
- the kernel image, e.g. `uImage`
- (opt.) the device tree binary, e. g. `meson8b_odroidc.dtb`
- (opt.) the initial ramdisk, e. g. `uInitrd`


## Stage 3 (Linux kernel)
The third stage is the loading of the Linux kernel.  However, before the Linux kernel takes control, u-boot passes a command line to the kernel containing essential parameters.  These parameters can be viewed after the operating system has booted by typing the following into a Terminal window:

```
$ cat /proc/cmdline
root=/dev/mmcblk0p2 rootwait rw console=ttyS0,115200n8 console=tty0 no_console_suspend vdaccfg=0xa000 logo=osd1,loaded,0x7900000,720p,full dmfc=3 cvbsmode=576cvbs hdmimode=1080p m_bpp=32 vout=hdmi disablehpd=true
```

The kernel initializes the hardware, mounts the root filesystem (according to the `root=...` kernel parameter) and passes the control flow to `/sbin/init`. 

## The shortcut
Hardkernel makes use of a special u-boot command called `cfgload`, which bypasses the ordinary boot process and provides a simplified u-boot configuration facility in a single file called `boot.ini`.
Configuration changes can be done easily by editing the `boot.ini` file, rather than modifying the u-boot environment, but this extension doesn’t provide any access to the interactive u-boot shell. 

You can boot one configuration at a time only by default. If a particular configuration change causes the system to hang during boot, you will need to remove the uSD or eMMC module from your device and revert this change by editing `boot.ini` on your notebook or PC.

# Understanding u-boot

## Disk layout and partitioning
Many ARM boards use a uSD/eMMC module to store the different u-boot components (SPL, u-boot executable, u-boot environment). In contrast to other devices which use flash based memory storage for this purpose (tablets, mobiles, ...), you cannot brick your device by an unsuccessful firmware update. 

The u-boot components are stored on reserved areas of the uSD/eMMC, before the first partition starts (all numbers denote the start and the end sector):

| Area               | ODROID-[C1(+)](http://odroid.com/dokuwiki/doku.php?id=en:c1_partition_table) | ODROID-[C2](http://odroid.com/dokuwiki/doku.php?id=en:c2_partition_table) | ODROID-[U3](http://odroid.com/dokuwiki/doku.php?id=en:u3_partition_table)/[XU3/XU4](http://odroid.com/dokuwiki/doku.php?id=en:xu3_partition_table) | [CuBox-i](http://wiki.solid-run.com/doku.php?id=products:imx6:software:development:u-boot) | [PINE64(+)](https://www.pine64.com/product)
|:---                    |         ---:|         ---:|         ---:|         ---:|           ---:|
| SPL (BL1/BL2)          |    0 -   63 |    0 -   96 |    1 -   62 |    1 -   83 | 16 - 143       |
| U-boot executable      |   64 - 1023 |   97 -  1431|   63 -  718 |   84 -  767 | 38192 - 40959 |
| **U-boot environment** | **1024 - 1087** | **1440 - 1503** | **1231 - 1262** | **768 - 783** | **file based** |
| 1st partition          | 3072 -  ... | 3072 -  ... | 3072 -  ... | 2048 -  ... | 40960 - ...   |

As you can see, there is no common canonical layout for the u-boot components across different boards. If you want to modify the partitioning with tools like `fdisk(8)`, you may keep in mind that `fdisk` always tries to create new partitions starting from sector 2048 by default.

U-boot tries to load the kernel image and additional files from the first partition of the designated boot device. Earlier u-boot versions supported only the vfat file system, which resulted in this typical partition layout:

| device           | label  | filesystem | mount point   |
| ---              | ---    | ---        | ---           |
| `/dev/mmcblk0p1` | boot   | vfat       | `/media/boot` |
| `/dev/mmcblk0p2` | rootfs | ext4       | `/`           |

Recent u-boot versions support reading files from ext4 file-systems, so there is no technical need to stick to the vfat boot partition. Although many installer images keep on using it due to convenience reasons, e.g. editing `boot.ini` on Windows / OS X which don't support ext4 out of the box.

## u-boot commands

The interactive u-boot shell offers a set of commands, depending on version and patch level. You can get a list of all supported commands by typing

    help

and

    help <command>

For further information please refer to the very extensive [official documentation](http://www.denx.de/wiki/view/DULG/UBootCommandLineInterface). 

## u-boot environment
The u-boot environment stores a set of variables in the form `<variable>=<value>`. If a saved environment is available u-boot initializes the working environment with these values or falls back to the built-in default environment. Variables are referenced by `${variable}`.

    printenv
prints out the whole set of variables, whereas
 
    printenv variable
prints the value of a single variable

    setenv variable value
sets a certain variable with the designated value 

    setenv variable
deletes a variable from the environment

    env -a
resets the u-boot environment with the built-in defaults

    saveenv
stores the current environment on the uSD or eMMC module. 
You can also [read and modify the u-boot environment](https://github.com/umiddelb/armhf/wiki/Get-more-out-of-%22Das-U-Boot%22#userland-access-to-the-u-boot-environment) when the system has started Linux.

## u-boot macros

U-boot uses variables to store scripts, so 

    setenv macro '...;'

will define a variable called `macro` containing a list of commands, delimited by a semicolon (`;`). Macros may be invoked by typing the “run” command:

    run macro

The most prominent macro is `bootcmd` which is run by default. Macros return a value (the return value of the command executed at last) which can be evaluated by an `if ... ; then ... ; else ...;` clause. Additional information is 'returned' by modifying specific variables, e.g. the `load` command uses the (global) variable `filesize` to return the number of bytes read from disk.

## Typical boot sequence

The macro `bootcmd` implements the boot sequence, executed in non-interactive mode. Prior to executing `bootcmd`, u-boot initializes the u-boot environment containing the configuration variables and macros. The typical steps inside `bootcmd` are:

### Load a custom environment from the boot partition
`bootcmd` looks for a text file called `uEnv.txt` on the boot partition, loads it and merges its contents with the existing u-boot environment by overriding values of existing variables. This step is optional.

### Load a custom environment from the boot partition
`bootcmd` will then look for a file called `boot.scr` on the boot partition, load the file and execute its contents without returning back to `bootcmd`. `boot.scr` contains compiled u-boot commands in a binary format. This step is optional.

### Load the kernel image from the boot partition
`bootcmd` looks for the kernel image. The u-boot variable `kernel` contains the actual filename, usually `zImage`. You can boot an alternate kernel image by changing the variable `kernel`.

### Load the device tree binary from the boot partition
The Linux kernel on ARM needs a low level device description (device tree) in binary format, either appended to the kernel image or as a separate file. Many platforms prefer loading the device tree binary as a separate file, which offers more flexibility, allowing distribution of a single installation image for different platforms, or tweaking of the device tree for different use cases. Some vendors let `bootcmd` decide on the actual device tree binary to load, depending on the board discovery performed by u-boot.

### Load the initial ramdisk archive from the boot partition
The bootcmd macro will finally try to load the initial ramdisk archive from a file called `uInitrd`.  This archive is created and updated by using the update-initramfs utility, which is usually done when a new kernel image has been installed. This step is optional.

## Userland access to the u-boot environment
When the system has booted up you can still modify the u-boot environment. The Ubuntu package `u-boot-tools` contains fw_printenv(8) and fw_setenv(8) for accessing the stored u-boot environment. After installing the package with 

    sudo apt-get -y install u-boot-tools

you need to configure the storage device and address information in the file `/etc/fw_env.config`, e.g. for the ODROID-C1:

    # <device>   <offset> <length>
    /dev/mmcblk0 0x80000   0x8000

and for the ODROID-XU3/XU4:

    # <device>   <offset> <length>
    /dev/mmcblk0 0x99E00   0x4000

You can test the configuration with 

    sudo fw_printenv bootdelay

The u-boot environment stored on disk contains a CRC checksum. If offset/length doesn't match you will receive a warning, like:

    Warning: Bad CRC, using default environment

To create an environment that can be modified with `u-boot-tools` halt the boot process during the early u-boot phase (you'll need to do this via an attached serial connection). At the u-boot prompt type 'saveenv'. u-boot will reply with a message of confirmation. Then `reset` to boot. When you next try `sudo fw_printenv` you should get a listing without the warning.

#### Important 

Do not attempt to modify the u-boot environment if you are getting the CRC error. In all likelihood you will render your device unbootable.

# Typical use cases for the ODROID C1

By default the ODROID-C1 is configured to boot via [`cfgload`](https://github.com/umiddelb/armhf/wiki/Get-more-out-of-%22Das-U-Boot%22#the-shortcut) with a very short boot delay. Increasing u-boot variable `bootdelay` gives you the chance to interrupt the automated boot process. You can use fw_setenv(8) to assign a new value to `bootdelay`:

    sudo fw_printenv bootdelay
    sudo fw_setenv bootdelay 3
  
prints the current value and sets the delay to 3 seconds.

## Boot an alternative kernel image

If you compile your own kernel from source, you really want to test the new kernel before overwriting the current one or keep a known working kernel as backup. Booting a different than the default kernel can be done by defining an u-boot macro which refers to different files on the boot partition. 

```
sudo setenv m_boot_ 'setenv bootargs "root=/dev/mmcblk0p2 rootwait rw console=ttyS0,115200n8 console=tty0 no_console_suspend vdaccfg=0xa000 logo=osd1,loaded,0x7900000,720p,full dmfc=3 cvbsmode=576cvbs hdmimode=1080p m_bpp=32 vout=hdmi disablehpd=true"; fatload mmc 0:1 0x21000000 _uImage;fatload mmc 0:1 0x22000000 uInitrd; fatload mmc 0:1 0x21800000 _meson8b_odroidc.dtb; fdt addr 21800000; fdt rm /mesonstream; fdt rm /vdec; fdt rm /ppmgr; fdt rm /mesonfb; bootm 0x21000000 0x22000000 0x21800000'
```

This defines the u-boot macro `m_boot_` which refers to the kernel image `_uImage` and the device binary `_meson8b_odroidc.dtb`. Unfortunately u-boot doesn't allow line feeds inside macros which makes them hard to read. If you insert a line feed after each `;` you will see the same command sequence as in `boot.ini`:

```
setenv bootargs "root=/dev/mmcblk0p2 rootwait rw console=ttyS0,115200n8 no_console_suspend vdaccfg=0xa000 logo=osd1,loaded,0x7900000,720p,full dmfc=3 cvbsmode=576cvbs hdmimode=1080p m_bpp=32 vout=hdmi disablehpd=true";
fatload mmc 0:1 0x21000000 _uImage;
fatload mmc 0:1 0x22000000 uInitrd;
fatload mmc 0:1 0x21800000 _meson8b_odroidc.dtb;
fdt addr 21800000;
fdt rm /mesonstream; 
fdt rm /vdec; 
fdt rm /ppmgr; 
fdt rm /mesonfb; 
bootm 0x21000000 0x22000000 0x21800000';
```

This is the effective command sequence during boot when configuring `boot.ini` to a headless configuration:

```
setenv vout_mode "hdmi"
setenv m_bpp "32"
setenv hpd "0"
setenv cec "0"
setenv vpu "0"
setenv hdmioutput "0"
```

Once you have defined the macro `m_boot_` and copied the kernel image and device tree binary to the boot partition with a leading '_' in the filename you can boot this kernel by interrupting u-boot and typing

    run m_boot_

at the u-boot shell prompt. 
   
## boot rootfs from a different partition, e.g from USB disk

You might have noticed the kernel parameter `root=...` which u-boot passes to the Linux kernel. The kernel will try to mount the root filesystem (`/`) from there. The root filesystem can be adressed in different ways:

* via device node: e.g. `root=/dev/sda1`
* via UUID filesystem identifier: e.g. `root=UUID=e139ce78-9841-40fe-8823-96a304a09859`

If you have only one USB storage device connected to your board you can safely address the root filesystem via device node. If you plan to dynamically connect/remove additional storage devices you're better off by addressing the root filesystem via the UUID identifier, otherwise the kernel might miss the root filesystem due to a 'forgotten' USB stick during next boot.

You can read the available UUIDs via `blkid`:

```
$ sudo blkid
/dev/mmcblk0p1: SEC_TYPE="msdos" LABEL="boot" UUID="E26F-2230" TYPE="vfat"
/dev/mmcblk0p2: LABEL="rootfs" UUID="e139ce78-9841-40fe-8823-96a304a09859" TYPE="ext4"
/dev/mmcblk0p3: LABEL="rootfs2" UUID="e139ce78-9841-40fe-8823-96a304a09860" TYPE="ext4"
/dev/sda1: LABEL="rootfs" UUID="e54a458d-6a66-4ed2-9394-7b22d2943ec9" TYPE="ext4"
```

The UUID can be set while creating a filesystem with `mkfs`:

```
$ sudo mkfs.ext4 -O ^has_journal -b 4096 -L rootfs -U e54a458d-6a66-4ed2-9394-7b22d2943ec9 /dev/sda1 
```
If you omit the parameter `-U` the UUID is chosen ramdomly.

As in the previous section you can define an additional u-boot macro which will then pass an alternative root filesystem to the kernel:
   
```
sudo setenv m_boot_usb 'setenv bootargs "root=/dev/sda1 rootwait rw console=ttyS0,115200n8 console=tty0 no_console_suspend vdaccfg=0xa000 logo=osd1,loaded,0x7900000,720p,full dmfc=3 cvbsmode=576cvbs hdmimode=1080p m_bpp=32 vout=hdmi disablehpd=true"; fatload mmc 0:1 0x21000000 uImage;fatload mmc 0:1 0x22000000 uInitrd; fatload mmc 0:1 0x21800000 meson8b_odroidc.dtb; fdt addr 21800000; fdt rm /mesonstream; fdt rm /vdec; fdt rm /ppmgr; fdt rm /mesonfb; bootm 0x21000000 0x22000000 0x21800000'
```

Although it is not recommended, if you need to clone the contents of a mounted root filesystem you may perform a bind mount before copying:

```
$ sudo mount /dev/sda1 /media/usb
$ sudo mount -o bind / /mnt
$ cd /mnt
$ sudo find . | sudo cpio -dump /media/usb
$ cd
$ sudo umount /mnt
$ sudo umount /media/usb
```

Which then allows you to boot from USB by typing the following at the u-boot shell prompt:

    run m_boot_usb

at the u-boot shell. 
# References
* [Porting Linux on ARM] (http://free-electrons.com/pub/conferences/2015/captronic/captronic-porting-linux-on-arm.pdf)

# To be continued ...
* boot from network
* [refactor existing macros](https://github.com/umiddelb/u-571)
* make the boot process platform aware in order to support multiple boards with one image 
* Boot a different OS (e.g. Android, FreeBSD)