
    wget http://download.fedoraproject.org/pub/fedora/linux/releases/21/Images/armhfp/Fedora-Minimal-armhfp-21-5-sda.raw.xz
    unxz Fedora-Minimal-armhfp-21-5-sda.raw.xz
    sudo losetup -r /dev/loop0 Fedora-Minimal-armhfp-21-5-sda.raw
    # lookup the start of the 3rd partition e.g. with fdisk
    sudo losetup -r /dev/loop3 Fedora-Minimal-armhfp-21-5-sda.raw -o $((1251328*512))
    sudo mount /dev/loop3 /mnt
    ( cd /mnt; sudo find * | sudo cpio -dump .../rootfs )
    sudo mount -o bind /dev ./rootfs/dev
    sudo mount -o bind /dev/pts ./rootfs/dev/pts
    sudo mount -t sysfs /sys ./rootfs/sys
    sudo mount -t proc /proc ./rootfs/proc
    sudo cp /proc/mounts ./rootfs/etc/mtab
    sudo chroot ./rootfs

    localedef -i en_GB -c -f UTF-8 en_GB.UTF-8
    localedef -i de_DE -c -f UTF-8 de_DE.UTF-8
    localectl set-locale LANG=en_GB.utf8
    ln -sf /usr/share/zoneinfo/right/Europe/Berlin localtime

    adduser odroid
    passwd odroid
    usermod -aG adm,cdrom odroid

    echo odroid-c1 > /etc/hostname
    echo "127.0.0.1       odroid-c localhost" >> /etc/hosts
    echo nameserver 8.8.8.8 > /etc/resolv.conf

    (cd /etc/systemd/system/getty.target.wants; ln -sf /usr/lib/systemd/system/serial-getty\@.service serial-getty@ttyS0.service)
    echo DEVICE=eth0 > /etc/sysconfig/network-scripts/ifcfg-eth0
    echo BOOTPROTO=dhcp >> /etc/sysconfig/network-scripts/ifcfg-eth0
    echo ONBOOT=yes >> /etc/sysconfig/network-scripts/ifcfg-eth0
    echo USERCTL=no >> /etc/sysconfig/network-scripts/ifcfg-eth0

    yum -y upgrade
    yum -y install gcc make git
    yum -y install screen wireless-tools ncurses-devel rcs bc lzop ntp usbutils most sysfsutils kernel-tools
    yum clean all

    cd /root
    mkdir kernel
    cd kernel
    git clone https://github.com/hardkernel/linux --single-branch -b odroidc-3.10.y
    cd linux
    make odroidc_defconfig
    make headers_install
    make -j 4 uImage modules
    make meson8b_odroidc.dtb
    make modules_install firmware_install
    cp arch/arm/boot/uImage /media/boot
    sudo cp arch/arm/boot/dts/meson8b_odroidc.dtb /media/boot
    exit

    sudo umount  ./rootfs/dev/pts
    sudo umount  ./rootfs/dev
    sudo umount  ./rootfs/sys
    sudo umount  ./rootfs/proc

