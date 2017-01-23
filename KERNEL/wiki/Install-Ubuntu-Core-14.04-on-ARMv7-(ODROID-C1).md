# Prepare boot media

    curl -sSL https://raw.githubusercontent.com/mdrjr/c1_uboot_binaries/master/bl1.bin.hardkernel | sudo dd of=/dev/mmcblk0 bs=1 count=442
    curl -sSL https://raw.githubusercontent.com/mdrjr/c1_uboot_binaries/master/bl1.bin.hardkernel | sudo dd of=/dev/mmcblk0 bs=512 skip=1 seek=1
    curl -sSL https://raw.githubusercontent.com/mdrjr/c1_uboot_binaries/master/u-boot.bin | sudo dd of=/dev/mmcblk0 bs=512 seek=64
    sync
    echo -e "o\nn\np\n1\n3072\n262143\nn\np\n2\n262144\n\nt\n1\nb\nw\n" | fdisk /dev/mmcblk0
    sync
    sudo mkfs.vfat -n boot /dev/mmcblk0p1 
    sudo mkfs.ext4 -O ^has_journal -b 4096 -L rootfs -U e139ce78-9841-40fe-8823-96a304a09859 /dev/mmcblk0p2 
    sudo mount /dev/mmcblk0p2 ./rootfs
    sudo mkdir -p ./rootfs/media/boot
    sudo mount /dev/mmcblk0p1 ./rootfs/media/boot

# Unpack Ubuntu Core

    curl -sSL http://cdimage.ubuntu.com/ubuntu-core/releases/14.04.3/release/ubuntu-core-14.04-core-armhf.tar.gz | sudo tar --numeric-owner -xpzvf - -C rootfs/

# Prepare chroot environment

    sudo mount -o bind /dev ./rootfs/dev
    sudo mount -o bind /dev/pts ./rootfs/dev/pts
    sudo mount -t sysfs /sys ./rootfs/sys
    sudo mount -t proc /proc ./rootfs/proc
    sudo cp /proc/mounts ./rootfs/etc/mtab
    sudo chroot ./rootfs

# Customize to your needs
```
locale-gen en_GB.UTF-8
locale-gen de_DE.UTF-8
export LC_ALL="en_GB.UTF-8"
update-locale LC_ALL=en_GB.UTF-8 LANG=en_GB.UTF-8 LC_MESSAGES=POSIX
dpkg-reconfigure locales
echo "Europe/Berlin" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata
echo armv7 > /etc/hostname
echo "127.0.0.1       armv7 localhost" >> /etc/hosts
echo "deb http://ports.ubuntu.com/ trusty main restricted universe multiverse" > /etc/apt/sources.list
echo "deb http://ports.ubuntu.com/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://ports.ubuntu.com/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://ports.ubuntu.com/ trusty-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "nameserver 8.8.8.8" > /etc/resolv.conf

dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

apt-get -q=2 -y install python-software-properties;
add-apt-repository -y ppa:ubuntu-toolchain-r/test;
apt-get update
apt-get -y upgrade
apt-get -y install gcc-5 g++-5
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 50
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 50
apt-get -y install software-properties-common u-boot-tools isc-dhcp-client ubuntu-minimal ssh
apt-get -y install cifs-utils screen wireless-tools iw curl libncurses5-dev cpufrequtils rcs aptitude make bc lzop man-db ntp usbutils pciutils lsof most sysfsutils linux-firmware linux-firmware-nonfree


apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AB19BAC9
echo "deb http://deb.odroid.in/c1/ trusty main" > /etc/apt/sources.list.d/odroid.list
echo "deb http://deb.odroid.in/ trusty main" >> /etc/apt/sources.list.d/odroid.list
apt-get update
mkdir -p /media/boot
apt-get -y install linux-image-c1 bootini
cp boot/uInitrd-3.10.* /media/boot/uInitrd 
cp boot/uImage-3.10.* /media/boot/uImage  

echo "auto lo" > /etc/network/interfaces.d/lo
echo "iface lo inet loopback" >> /etc/network/interfaces.d/lo
echo "auto eth0" >/etc/network/interfaces.d/eth0
echo "iface eth0 inet dhcp" >>/etc/network/interfaces.d/eth0
echo "start on stopped rc or RUNLEVEL=[12345]" > /etc/init/ttyS0.conf
echo "stop on runlevel [!12345]" >> /etc/init/ttyS0.conf
echo "respawn" >> /etc/init/ttyS0.conf
echo "exec /sbin/getty -L 115200 ttyS0 vt102" >> /etc/init/ttyS0.conf

adduser ubuntu
usermod -aG adm,cdrom,sudo,plugdev ubuntu
```

# Tidy up

    apt-get clean

    rm /sbin/initctl
    dpkg-divert --local --rename --remove /sbin/initctl

    exit
    sudo umount ./rootfs/dev/pts
    sudo umount ./rootfs/sys
    sudo umount ./rootfs/proc
    sudo umount ./rootfs/dev
    sudo umount ./rootfs/media/boot
    sudo umount ./rootfs