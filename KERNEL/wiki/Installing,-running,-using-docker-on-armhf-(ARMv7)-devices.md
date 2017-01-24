# Synopsis
This tutorial describes useful things if you want to run [Docker](https://www.docker.com/) on ARMv7 based devices. I don't aim to compete with existing tutorials, they all do a great job. But you shouldn't expect to run the examples mentioned in these tutorials on you ARM device. At the end you should be able to run the examples in a slightly modified way. 

The people from the ODROID Magazine kindly published this tutorial in their [2015-03 issue](http://forum.odroid.com/viewtopic.php?f=7&t=11052).   


# Before you start

I'm running ubuntu 14.04.3 on my ARMv7 based devices, which makes it easier to install and run Docker. If you prefer to run a different linux flavor, you might experience little deviations (package naming, etc., if you run Fedora 22 you can continue [here](https://github.com/umiddelb/armhf/wiki/Installing,-running,-using-docker-on-armhf-(ARMv7)-devices#installing-docker-on-fedora-22-armhfp)). I created my ubuntu userland once from scratch and use it among the different ARMv7 devices. Porting ubuntu to a different device means re-using the userland, then compiling/replacing the vendor specific kernel and bootloader.

You shouldn't be afraid of compiling a customized linux kernel, since the most vendor specific linux kernels don't include support for the aufs filesystem. Although Docker will run on kernels without aufs, it will speed up significantly on aufs enabled platforms. Furthermore some vendors may not include all features needed for Docker to run properly with their default kernel configuration.  

# Install Docker from the ubuntu Repository

Ubuntu 14.04.3 includes a docker.io package (which is actually version 1.6.2).

    $ sudo apt-get install lxc aufs-tools cgroup-lite apparmor docker.io

will install the binary, start-up scripts, etc.. But, it is very likely that the Docker service won't start successfully after installing. Usually there is a specific kernel feature not available which Docker relies on. _In the meantime, the default ODROID images and kernel packages contain docker enabled kernel images already, so are almost done by installing the packages mentioned above and you might go to the [docker upgrade procedure](https://github.com/umiddelb/armhf/wiki/Installing,-running,-using-docker-on-armhf-(ARMv7)-devices#updating-from-docker-version-101) directly._

# See what's missing

Running `/usr/bin/docker -D -d` will give you a clue about the actual reason, why the Docker daemon refuses to start. The Docker developers provide a (bash-) shell script which queries whether all Docker-related requirements are met by a particular kernel config. [check-config.sh](https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh) will either check the config of the running kernel (accessible via `/proc/config.gz`) or will try to read the kernel source's config file specified on the command line. So 

    $ curl -L https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh | /bin/bash /dev/stdin /path/to/.config

will be your friend.

![output of check-config](https://raw.githubusercontent.com/umiddelb/armhf/master/img/check-config.png)


# Compile your custom linux kernel

Many vendors publish their (slightly) modified kernel sources for their ARM devices and instructions how to install the compiled kernel image. I use the following instructions for compiling the kernel sources. To do this, you need to install a compiler tool-chain (`make`, `gcc`, ...) and some '3rd party' tools (`bc`, `lzop`, `u-boot-tools`). Be careful, this will overwrite the default kernel image. You may consider to take a backup of your actual kernel.

`make menuconfig` gives you a much more user-friendly interface then editing the `.config` with you preferred text editor.

## [Utilite Pro](http://www.compulab.co.il/utilite-computer/wiki/index.php/Utilite_Linux_Kernel_3.10)

    $ git clone --depth 1 --single-branch -b 'utilite/devel' https://github.com/utilite-computer/linux-kernel 
    $ make cm_fx6_defconfig
    $ make clean                                                          
    $ make -j 4 zImage dtbs modules
    $ sudo cp arch/arm/boot/zImage arch/arm/boot/dts/*.dtb > /boot
    $ make modules_install
    $ make firmware_install

## [CuBox-i Pro](http://www.solid-run.com/wiki/index.php?title=Building_the_kernel_and_u-boot_for_the_CuBox-i_and_the_HummingBoard)
This kernel config has already enabled everything you need in order to run docker (with the exception of aufs) when `make imx_v7_cbi_hb_defconfig` has finished.  

    $ git clone --depth 1 --single-branch -b 3.14-1.0.x-mx6-sr https://github.com/SolidRun/linux-fslc.git
    $ cd linux-fslc 
    $ make imx_v7_cbi_hb_defconfig
    $ make clean
    $ make -j 4 zImage dtbs modules
    $ sudo cp arch/arm/boot/zImage arch/arm/boot/dts/*.dtb /boot
    $ sudo make modules_install
    $ sudo make firmware_install

## [ODROID-C1](http://odroid.com/dokuwiki/doku.php?id=en:c1_ubuntu_release_note_v1.2)
The ODROID kernel sources for C1 have integrated support for Docker and aufs. There is no need to alter any of the kernel options via `make menuconfig`. 
_In the meantime, the default ODROID images and kernel packages contain docker enabled kernel images already, so you may skip this part and go to the [docker upgrade procedure](https://github.com/umiddelb/armhf/wiki/Installing,-running,-using-docker-on-armhf-(ARMv7)-devices#updating-from-docker-version-101) directly._

    $ git clone --depth 1 --single-branch -b odroidc-3.10.y https://github.com/hardkernel/linux
    $ cd linux
    $ make odroidc_defconfig
    $ make clean
    $ make -j 4 uImage dtbs modules
    $ sudo cp arch/arm/boot/uImage arch/arm/boot/dts/meson8b_odroidc.dtb /media/boot
    $ sudo make modules_install
    $ sudo make firmware_install

## [ODROID-U3](http://odroid.com/dokuwiki/doku.php?id=en:u3_building_kernel)
The ODROID kernel sources for U3 have integrated support for Docker and aufs. There is no need to alter any of the kernel options via `make menuconfig`. 
_In the meantime, the default ODROID images and kernel packages contain docker enabled kernel images already, so you may skip this part and go to the [docker upgrade procedure](https://github.com/umiddelb/armhf/wiki/Installing,-running,-using-docker-on-armhf-(ARMv7)-devices#updating-from-docker-version-101) directly._

    $ git clone --depth 1 --single-branch -b odroid-3.8.y https://github.com/hardkernel/linux
    $ cd linux 
    $ make odroidu_defconfig
    $ make clean
    $ make -j 4
    $ sudo make modules_install
    $ sudo cp arch/arm/boot/zImage /media/boot

## [ODROID-XU3](http://odroid.com/dokuwiki/doku.php?id=en:xu3_building_kernel)
The ODROID kernel sources for XU3 have integrated support for Docker and aufs. There is no need to alter any of the kernel options via `make menuconfig`.
_In the meantime, the default ODROID images and kernel packages contain docker enabled kernel images already, so you may skip this part and go to the [docker upgrade procedure](https://github.com/umiddelb/armhf/wiki/Installing,-running,-using-docker-on-armhf-(ARMv7)-devices#updating-from-docker-version-101) directly._

    $ git clone --depth 1 --single-branch -b odroidxu3-3.10.y https://github.com/hardkernel/linux
    $ cd linux 
    $ make odroidxu3_defconfig
    $ make clean
    $ make -j 8
    $ sudo make modules_install
    $ sudo cp arch/arm/boot/zImage arch/arm/boot/dts/exynos5422-odroidxu3.dtb /media/boot

## [aufs integration](http://aufs.sourceforge.net/)

As I said before, Docker will speed up significantly if the kernel supports the [aufs filesystem](http://aufs.sourceforge.net/). I've used the standalone version (kernel module only) so far.

If you have one of the ODROID devices mentioned above, you can skip this part. Their kernel sources have integrated support for aufs already.  

### Integration into the linux kernel sources: 
  
    $ cd <kernel source directory>
    $ git clone git://git.code.sf.net/p/aufs/aufs3-standalone aufs3-standalone.git
    $ cd aufs3-standalone.git
    $ git checkout origin/aufs3.10     # 3.10 .. 3.10.25
    $ git checkout origin/aufs3.10.x   # 3.10.26 and above
    $ git checkout origin/aufs3.14     # 3.14 .. 3.14.20
    $ git checkout origin/aufs3.14.21+ # 3.14.21 .. 3.14.39
    $ git checkout origin/aufs3.14.40+ # 3.14.40 and above
    $ rm include/uapi/linux/Kbuild     # this will keep your kernel sources config management from being damaged 
    $ cp -rp *.patch fs include Documentation ../
    $ cd ..
    $ cat aufs3-kbuild.patch aufs3-base.patch aufs3-mmap.patch aufs3-standalone.patch | patch -p1

The aufs release numbering corresponds to the kernel version, so you may checkout `origin/aufs3.14` for a linux 3.14.x kernel source code. The `3.10` aufs comes with two branches, `3.10` and `3.10.x`. Unfortunately, the aufs developers decided to discontinue the support for kernels below 3.14 with the beginning of 2015 and removed the information that `3.10.x` branch has to be used for kernel versions starting with 3.10.26.  

    $ make oldconfig
    ...
      Aufs (Advanced multi layered unification filesystem) support (AUFS_FS) [N/m/y/?] (NEW) m
        Maximum number of branches
        > 1. 127 (AUFS_BRANCH_MAX_127) (NEW)
          2. 511 (AUFS_BRANCH_MAX_511) (NEW)
          3. 1023 (AUFS_BRANCH_MAX_1023) (NEW)
          4. 32767 (AUFS_BRANCH_MAX_32767) (NEW)
        choice[1-4?]: 1
        Detect direct branch access (bypassing aufs) (AUFS_HNOTIFY) [N/y/?] (NEW) y
          method
          > 1. fsnotify (AUFS_HFSNOTIFY) (NEW)
          choice[1]: 1
        NFS-exportable aufs (AUFS_EXPORT) [N/y/?] (NEW) y
        support for XATTR/EA (including Security Labels) (AUFS_XATTR) [N/y/?] (NEW) y
        File-based Hierarchical Storage Management (AUFS_FHSM) [N/y/?] (NEW) y
        Readdir in userspace (AUFS_RDU) [N/y/?] (NEW) y
        Show whiteouts (AUFS_SHWH) [N/y/?] (NEW) y
        Ramfs (initramfs/rootfs) as an aufs branch (AUFS_BR_RAMFS) [N/y/?] (NEW) y
        Fuse fs as an aufs branch (AUFS_BR_FUSE) [N/y/?] (NEW) y
        Hfsplus as an aufs branch (AUFS_BR_HFSPLUS) [Y/n/?] (NEW) y
        Debug aufs (AUFS_DEBUG) [N/y/?] (NEW) n
    
    configuration written to .config
    $ make savedefconfig 

This will add the aufs related kernel configuration items to your existing config. Please choose 'm' for the aufs support.

## OverlayFS

Nowadays Docker also supports OverlayFS introduced with the 3.18 Linux kernel. So if you've managed to run linux 3.18 on your arm device OverlayFS could be a replacement for aufs. This [article](https://docs.docker.com/engine/userguide/storagedriver/overlayfs-driver/) may help you to set up Docker with OverlayFS.

Now it's time to recompile and install the new kernel.

# First steps with Docker

## Try Docker with your customized kernel

If everything went well the Docker service will run on your device and listens for service requests. 

    $ sudo docker info
    Containers: 0
    Images: 0
    Storage Driver: aufs
     Root Dir: /var/lib/docker/aufs
     Backing Filesystem: extfs
     Dirs: 0
    Execution Driver: native-0.2
    Kernel Version: 3.10.66-aufs
    Operating System: Ubuntu 14.04.2 LTS
    CPUs: 4
    Total Memory: 983.4 MiB
    Name: odroid-c1
    ID: 324D:YXY2:2XQP:CATB:KIQD:AFXA:UZBQ:IEPO:WSB5:3Y2R:O5QU:FRDU

## Which Docker base image to take?

Most of the Docker images are made for the x86 platform and docker itself isn't platform aware, although the Docker images know on which platform they have been created:

    $ sudo docker images
    REPOSITORY                TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
    <none>                    <none>              d8115ff9b785        22 hours ago        301.5 MB
    armv7/armhf-ubuntu_core   14.04               c11f1521cacf        2 weeks ago         159 MB
    $ sudo docker inspect d8115ff9b785 | jq '.[] | .Architecture'
    "arm"


So running

    $ sudo docker run ubuntu /bin/echo 'Hello world'

will yield

    FATA[0205] Error response from daemon: Cannot start container 9b55520a44ad4c069cc577afa51983713afb8e96ebe55a736e0819706b94f10b: exec format error 

Most of the Docker images for ARMv7 devices in the Docker registry have a name starting with `armhf-...`. You may search for them:

```
$ sudo docker search armhf-
umiddelb@armh0:~$ sudo docker search armhf-
NAME                          DESCRIPTION                                     STARS     OFFICIAL   AUTOMATED
mazzolino/armhf-ubuntu        Ubuntu-Core images for armhf (ARMv7) devices    4
armv7/armhf-ubuntu            'official' ubuntu docker images for the AR...   4
mazzolino/armhf-debian        Debian Wheezy base image for armhf devices      4
armv7/armhf-archlinux         archlinux arm docker image for the ARMv7(a...   3
armv7/armhf-ubuntu_core       ubuntu core docker images for the ARMv7(ar...   2
hominidae/armhf-ubuntu        ubuntu trusty/14.04 image (minbase) for ar...   2
armv7/armhf-fedora            minimal fedora 21, 20 docker images for th...   1
hominidae/armhf-wheezy        armhf image of Debian Wheezy, made with de...   1
armbuild/ubuntu-debootstrap   ARMHF port of ubuntu-debootstrap                1                    [OK]
dpniel/dekko-armhf            armhf utopic image to build dekko click pa...   0
troyfontaine/armhf-haproxy    HAProxy for ARMHF                               0
hominidae/armhf-supervisord   ubuntu trusty/14.04 for armhf architecure ...   0
mazzolino/armhf-twister       Twister for armhf / armv7 devices               0
hominidae/armhf-archlinux     ArchLinux base image for armhf architectur...   0
onlinelabs/armhf-ubuntu                                                       0
chanwit/fedora-armhf          Fedora for the armhf architecture               0
moul/armhf-busybox                                                            0                    [OK]
armv7/armhf-baseimage         ubuntu docker images for the ARMv7(armhf) ...   0
mazzolino/armhf-prosody       Secured Prosody XMPP server for armhf (ARM...   0
dehy/armhf-couchdb            ARMHF port of klaemo/couchdb                    0
mazzolino/armhf-tiddlywiki    Tiddywiki5 on NodeJS for armhf (ARMv7) dev...   0
zsoltm/ubuntu-armhf           Ubuntu 14.04.1 minimal install, latest upd...   0
mazzolino/armhf-nginx         Nginx image for armhf devices                   0
troyfontaine/armhf-nginx      Nginx for ARMHF                                 0
rcarmo/armhf-ubuntu           Ubuntu 14.04.2 for armhf devices                0
```
I publish my Docker images using the armv7 profile on [dockerhub](https://hub.docker.com/r/armv7/) . So let's try the same with `armv7/armhf-ubuntu_core`:

    $ sudo docker run armv7/armhf-ubuntu_core /bin/echo 'Hello world'
    Unable to find image 'armv7/armhf-ubuntu_core:latest' locally
    Pulling repository armv7/armhf-ubuntu_core
    c3802ac1b0ad: Download complete 
    Status: Downloaded newer image for armv7/armhf-ubuntu_core:latest
    Hello world

This time I've used a different device which hasn't downloaded the image before. It will be part of the local image cache now:

    $ sudo docker images
    REPOSITORY                TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
    armv7/armhf-ubuntu_core   latest              c3802ac1b0ad        About an hour ago   163.5 MB

## Become more familiar with Docker

There are lots of excellent resources helping you to get a better understanding of Docker. You may visit

* <http://docs.docker.com/userguide/>
* <https://www.youtube.com/watch?v=pYZPd78F4q4>
* <https://github.com/veggiemonk/awesome-docker>

and subscribe to the weekly Docker [newsletter](https://www.docker.com/subscribe_newsletter/).

# Updating from Docker version 1.0.1

You may have experienced a tedious bug in Docker 1.0.1 which will from time to time prevent containers from starting:

    $ sudo docker run armv7/armhf-ubuntu_core /bin/echo 'Hello world'
    2015/01/15 17:57:10 finalize namespace drop capabilities operation not permitted

This [bug](https://github.com/docker/docker/issues/4556) seems to be fixed in Docker version 1.4.0. You can build Docker 1.4.0 from source with Docker 1.0.1 but you need [patched sources](https://github.com/resin-io/docker), otherwise the build-in fuse will prevent Docker from starting:

    FATA[0000] The Docker runtime currently only supports amd64 (not arm). This will change in the future. Aborting.

The Docker [wiki pages](https://docs.docker.com/contributing/devenvironment/) will guide you how to build the Docker binary from source.

Starting with [release 1.5.0](http://blog.docker.com/2015/02/docker-1-5-ipv6-support-read-only-containers-stats-named-dockerfiles-and-more/) the Docker developers [removed](https://github.com/docker/docker/commit/7d7a002e51a1a1172f09741896f0a6c001438a49) the 'fuse' which explicitly requires the amd64 platform and integrated most of the [patches](https://github.com/resin-io/docker/compare/docker:master...master) making Docker 32 bit safe. You can build Docker for ARMv7 with the latest original sources now. The only thing you still need is a slightly modified Dockerfile for the armhf/ARMv7 platform and then:

    $ git clone -b 'v1.9.1' --depth 1 --single-branch https://github.com/docker/docker.git
    $ cd docker
    $ curl -L https://github.com/umiddelb/armhf/raw/master/Dockerfile.armv7 > Dockerfile
    $ sudo make build
    $ sudo make binary
    $ sudo service docker.io stop
    $ sudo cp bundles/1.9.1/binary/docker-1.9.1 /usr/bin
    $ (cd /usr/bin; sudo mv docker _docker; sudo ln -sf docker-1.9.1 docker) 
    $ sudo service docker.io start
    ...

It is very likely that the bug mentioned above will interrupt the build process. In this case you have to issue the `sudo make build` more than once. You may download the final Docker binary [here](https://github.com/umiddelb/armhf/raw/master/bin/docker-1.9.1), if you start feeling tired.

The binary itself is linked statically, it will run on other linux flavours as well (e.g. fedora or archlinux):

    $ file /usr/bin/docker-1.9.1 
    docker-1.9.1: ELF 32-bit LSB  executable, ARM, EABI5 version 1 (SYSV), statically linked, for GNU/Linux 2.6.32, BuildID[sha1]=899c1d9a7227a5d26da60ebc14abf110c26d2318, not stripped

Just replace the existing Docker binary in `/usr/bin` with the new one and you're done:

```
$ sudo docker version
Client:
 Version:      1.9.1
 API version:  1.21
 Go version:   go1.4.3
 Git commit:   a34a1d5-dirty
 Built:        Thu Jan 28 10:28:47 UTC 2016
 OS/Arch:      linux/arm

Server:
 Version:      1.9.1
 API version:  1.21
 Go version:   go1.4.3
 Git commit:   a34a1d5-dirty
 Built:        Thu Jan 28 10:28:47 UTC 2016
 OS/Arch:      linux/arm
```

# Docker 1.11 runC and containerd

Docker 1.11 introduced OCI technologies runC and containerd (see the [Blog Post](https://blog.docker.com/2016/04/docker-engine-1-11-runc/) ). As the upgrade requires additional daemon services to start, it is necessary to replace the service start/stop script in addition to the docker binary. You can build 1.11.2 as follows

    $ git clone -b 'v1.11.2' --depth 1 --single-branch https://github.com/docker/docker.git
    $ cd docker
    $ curl -L https://github.com/umiddelb/armhf/raw/master/Dockerfile.armv7 > Dockerfile
    $ sudo make build
    $ sudo make binary
    $ sudo service docker stop
    $ sudo cp bundles/1.11.2/binary/docker-1.11.2 /usr/bin
    $ (cd /usr/bin; sudo mv docker _docker; sudo ln -sf docker-1.11.2 docker) 
    $ (cd bundles/1.11.2/binary; sudo cp docker-containerd docker-containerd-shim docker-runc /usr/bin) 
    $ sudo cp contrib/init/upstart/docker.conf /etc/init 
    $ sudo service docker start

# Installing Docker on Fedora 22 (armhfp)

The Fedora developers issued a Docker rpm package for armhfp recently, thanks to @vpavlin:

    $ sudo yum install lxc bridge-utils device-mapper device-mapper-libs libsqlite3x docker-registry docker-storage-setup docker-io