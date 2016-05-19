#!/usr/bin/env bash

########################################################################
#
# Copyright (C) 2015 Martin Wimpress <code@ubuntu-mate.org>
# Copyright (C) 2015 Rohith Madhavan <rohithmadhavan@gmail.com>
# Copyright (C) 2015 Ryan Finnie <ryan@finnie.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
########################################################################

set -ex

if [ -f build-settings.sh ]; then
    source build-settings.sh
else
    echo "ERROR! Could not source build-settings.sh."
    exit 1
fi

if [ $(id -u) -ne 0 ]; then
    echo "ERROR! Must be root."
    exit 1
fi

# Mount host system
function mount_system() {
    # In case this is a re-run move the cofi preload out of the way
    if [ -e $R/etc/ld.so.preload ]; then
        mv -v $R/etc/ld.so.preload $R/etc/ld.so.preload.disable
    fi
    mount -t proc none $R/proc
    mount -t sysfs none $R/sys
    mount -o bind /dev $R/dev
    mount -o bind /dev/pts $R/dev/pts
    echo "nameserver 8.8.8.8" > $R/etc/resolv.conf
}

# Unmount host system
function umount_system() {
    umount -l $R/sys
    umount -l $R/proc
    umount -l $R/dev/pts
    umount -l $R/dev
    echo "" > $R/etc/resolv.conf
}

function sync_to() {
    local TARGET="${1}"
    if [ ! -d "${TARGET}" ]; then
        mkdir -p "${TARGET}"
    fi
    # rsync -a --progress --delete ${R}/ ${TARGET}/
    rsync -a --delete ${R}/ ${TARGET}/
}

function generate_locale() {
    # Setup default locale
    cat <<EOM >$R/etc/default/locale
LANG="en_US.UTF-8"
LANGUAGE="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_PAPER="en_US.UTF-8"
LC_NAME="en_US.UTF-8"
LC_ADDRESS="en_US.UTF-8"
LC_TELEPHONE="en_US.UTF-8"
LC_MEASUREMENT="en_US.UTF-8"
LC_IDENTIFICATION="en_US.UTF-8"
LC_CTYPE="UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_ALL="en_US.UTF-8"
EOM

    for LOCALE in $(chroot $R locale | cut -d'=' -f2 | grep -v : | sed 's/"//g' | uniq); do
        if [ -n "${LOCALE}" ]; then
            chroot $R locale-gen $LOCALE
            chroot $R update-locale LC_ALL=$LOCALE
        fi
    done
    chroot $R dpkg-reconfigure --frontend=noninteractive locales
}

# Set up initial sources.list
function apt_sources() {
    cat <<EOM >$R/etc/apt/sources.list
deb http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
EOM

    cat <<EOM >$R/etc/apt/apt.conf.d/50raspi
# Never use pdiffs, current implementation is very slow on low-powered devices
Acquire::PDiffs "0";
EOM

}

function apt_update_only() {
    chroot $R apt-get update
}

function apt_clean() {
    chroot $R apt-get -y autoremove
    chroot $R apt-get clean
}

function create_groups() {
#    chroot $R groupadd -f --system gpio
#    chroot $R groupadd -f --system i2c
    chroot $R groupadd -f --system input
#    chroot $R groupadd -f --system spi

    # Create adduser hook
# 2016-04-03 original line was following
# usermod -a -G adm,gpio,i2c,input,spi,video $1

    cat <<'EOM' >$R/usr/local/sbin/adduser.local
#!/bin/sh
# This script is executed as the final step when calling `adduser`
# USAGE:
#   adduser.local USER UID GID HOME

# Add user to the Raspberry Pi specific groups
usermod -a -G adm,input $1
EOM
    chmod +x $R/usr/local/sbin/adduser.local
}

# Create default user
function create_user() {
    local DATE=$(date +%m%H%M%S)
    local PASSWD=$(mkpasswd -m sha-512 ${USERNAME} ${DATE})

    if [ ${OEM_CONFIG} -eq 1 ]; then
        chroot $R addgroup --gid 29999 oem
        chroot $R adduser --gecos "OEM Configuration (temporary user)" --add_extra_groups --disabled-password --gid 29999 --uid 29999 ${USERNAME}
    else
        chroot $R adduser --gecos "${FLAVOUR_NAME}" --add_extra_groups --disabled-password ${USERNAME}
    fi
    chroot $R usermod -a -G sudo -p ${PASSWD} ${USERNAME}
}

# Prepare oem-config for first boot.
function prepare_oem_config() {
    if [ ${OEM_CONFIG} -eq 1 ]; then
        chroot $R /bin/systemctl set-default oem-config.target
    fi
}

function configure_ssh() {
    chroot $R apt-get -y install openssh-server
    cat <<EOM >$R/etc/systemd/system/sshdgenkeys.service
[Unit]
Description=SSH key generation on first startup
Before=ssh.service
ConditionPathExists=|!/etc/ssh/ssh_host_key
ConditionPathExists=|!/etc/ssh/ssh_host_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key.pub

[Service]
ExecStart=/usr/bin/ssh-keygen -A
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=ssh.service
EOM

    mkdir -p $R/etc/systemd/system/ssh.service.wants
    chroot $R ln -s /etc/systemd/system/sshdgenkeys.service /etc/systemd/system/ssh.service.wants
}

function configure_network() {
    # Set up hosts
    echo ${FLAVOUR} >$R/etc/hostname
    cat <<EOM >$R/etc/hosts
127.0.0.1       localhost
# ::1             localhost ip6-localhost ip6-loopback
# ff02::1         ip6-allnodes
# ff02::2         ip6-allrouters

127.0.1.1       ${FLAVOUR}
EOM

    # Set up interfaces
    if [ "${FLAVOUR}" != "ubuntu-minimal" ] && [ "${FLAVOUR}" != "ubuntu-standard" ]; then
        cat <<EOM >$R/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

# The loopback network interface
auto lo
iface lo inet loopback
EOM
    else
        cat <<EOM >$R/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

# The loopback network interface
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOM
    fi
}

function setup_developer_package() {
    chroot $R apt-get -y install sudo whois
}

function setup_kernel() {
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    # gdebi-core used for installing copies-and-fills and omxplayer
    chroot $R apt-get -y install gdebi-core
    local COFI="http://archive.raspberrypi.org/debian/pool/main/r/raspi-copies-and-fills/raspi-copies-and-fills_0.5-1_armhf.deb"

    # Install the RPi PPA
    chroot $R apt-add-repository -y ppa:ubuntu-pi-flavour-makers/ppa
    chroot $R apt-get update

    # Firmware Kernel installation
    chroot $R apt-get -y install raspberrypi-bootloader rpi-update
    chroot $R ROOT_PATH="${R}/" BOOT_PATH="${R}/boot/firmware" rpi-update 6d158adcc0cfa03afa17665715706e6e5f0750d2

    # Hardware - Create a fake HW clock and add rng-tools
    chroot $R apt-get -y install fake-hwclock rng-tools

    # 2016-05-15 We do not need this. Rather, stable kernel is more necessary.
    # Load sound module on boot and enable HW random number generator
#    cat <<EOM >$R/etc/modules-load.d/rpi2.conf
#bcm2708_rng
#EOM

    # Blacklist platform modules not applicable to the RPi2
    cat <<EOM >$R/etc/modprobe.d/blacklist-rpi.conf
blacklist snd_bcm2835
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
EOM

    # Disable TLP
    if [ -f $R/etc/default/tlp ]; then
        sed -i s'/TLP_ENABLE=1/TLP_ENABLE=0/' $R/etc/default/tlp
    fi

    # udev rules
    printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"\n' >> $R/etc/udev/rules.d/99-com.rules

    # copies-and-fills
    wget -c "${COFI}" -O $R/tmp/cofi.deb
    chroot $R gdebi -n /tmp/cofi.deb

    # Disabled cofi so it doesn't segfault when building via qemu-user-static
    mv -v $R/etc/ld.so.preload $R/etc/ld.so.preload.disable

    # Set up fstab
    cat <<EOM >$R/etc/fstab
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ${FS}   defaults,noatime  0       1
/dev/mmcblk0p1  /boot/          vfat    defaults          0       2
EOM

    # Set up firmware config
    wget -c https://raw.githubusercontent.com/Evilpaul/RPi-config/master/config.txt -O $R/boot/config.txt
    if [ "${FLAVOUR}" == "ubuntu-minimal" ] || [ "${FLAVOUR}" == "ubuntu-standard" ]; then
        echo "net.ifnames=0 biosdevname=0 dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=${FS} elevator=deadline rootwait quiet splash" > $R/boot/cmdline.txt
    else
        echo "dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=${FS} elevator=deadline rootwait quiet splash" > $R/boot/cmdline.txt
        sed -i 's/#framebuffer_depth=16/framebuffer_depth=32/' $R/boot/config.txt
        sed -i 's/#framebuffer_ignore_alpha=0/framebuffer_ignore_alpha=1/' $R/boot/config.txt
    fi

    # Save the clock
    chroot $R fake-hwclock save
}

# this is from Ubuntu Raspberry PI page. Does not work
function setup_alternative_kernel() {
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    # Install the RPi PPA
    chroot $R apt-add-repository -y ppa:ubuntu-raspi2/ppa-rpi3
    chroot $R apt-get update

    # Firmware Kernel installation
    chroot $R apt-get -y install u-boot-rpi linux-raspi2 linux-firmware-raspi2 flash-kernel
    # chroot $R apt-get -y install linux-firmware 

    # gdebi-core used for installing copies-and-fills and omxplayer
    chroot $R apt-get -y install gdebi-core
    local COFI="http://archive.raspberrypi.org/debian/pool/main/r/raspi-copies-and-fills/raspi-copies-and-fills_0.5-1_armhf.deb"

    # Install the RPI2 DT-compatible u-boot image.
    wget -O $R/tmp/mkknlimg https://raw.githubusercontent.com/raspberrypi/tools/master/mkimage/mkknlimg
    chmod 0755 $R/tmp/mkknlimg 
    $R/tmp/mkknlimg --dtok $R/usr/lib/u-boot/rpi_2/u-boot.bin $R/boot/firmware/uboot.bin

    # Blacklist platform modules not applicable to the RPI
    cat <<EOM >$R/etc/modprobe.d/blacklist-rpi.conf
blacklist snd_bcm2835
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
EOM

    # Disable TLP
    if [ -f $R/etc/default/tlp ]; then
        sed -i s'/TLP_ENABLE=1/TLP_ENABLE=0/' $R/etc/default/tlp
    fi

    # udev rules
    printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"\n' >> $R/etc/udev/rules.d/99-com.rules

    # copies-and-fills
    wget -c "${COFI}" -O $R/tmp/cofi.deb
    chroot $R gdebi -n /tmp/cofi.deb

    # Disabled cofi so it doesn't segfault when building via qemu-user-static
    mv -v $R/etc/ld.so.preload $R/etc/ld.so.preload.disable

    # Set up fstab
    cat <<EOM >$R/etc/fstab
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ${FS}   defaults,noatime  0       1
/dev/mmcblk0p1  /boot/          vfat    defaults          0       2
EOM

    # BOOT config
    cat <<EOM >$R/boot/firmware/config.txt
kernel=uboot.bin
EOM

    # Set up firmware config
    cat <<EOM >$R/boot/firmware/cmdline.txt
net.ifnames=0 biosdevname=0 dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=${FS} elevator=deadline rootwait quiet splash
EOM

    # update bootloader
    #chroot $R update-initramfs -c
    chroot $R flash-kernel
}

function setup_minimal_kernel() {
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    # Install the RPi PPA
    chroot $R apt-add-repository -y ppa:ubuntu-pi-flavour-makers/ppa
    chroot $R apt-get update

    # Firmware Kernel installation
    chroot $R apt-get -y install raspberrypi-bootloader rpi-update
    chroot $R rpi-update

    # gdebi-core used for installing copies-and-fills and omxplayer
    chroot $R apt-get -y install gdebi-core
    local COFI="http://archive.raspberrypi.org/debian/pool/main/r/raspi-copies-and-fills/raspi-copies-and-fills_0.5-1_armhf.deb"

    # Blacklist platform modules not applicable to the RPI
    cat <<EOM >$R/etc/modprobe.d/blacklist-rpi.conf
blacklist snd_bcm2835
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
EOM

    # Disable TLP
    if [ -f $R/etc/default/tlp ]; then
        sed -i s'/TLP_ENABLE=1/TLP_ENABLE=0/' $R/etc/default/tlp
    fi

    # udev rules
    printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"\n' >> $R/etc/udev/rules.d/99-com.rules

    # copies-and-fills
    wget -c "${COFI}" -O $R/tmp/cofi.deb
    chroot $R gdebi -n /tmp/cofi.deb

    # Disabled cofi so it doesn't segfault when building via qemu-user-static
    mv -v $R/etc/ld.so.preload $R/etc/ld.so.preload.disable

    # Set up fstab
    cat <<EOM >$R/etc/fstab
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ${FS}   defaults,noatime  0       1
/dev/mmcblk0p1  /boot/          vfat    defaults          0       2
EOM

    # BOOT config : WARNING this is /boot/!
    cat <<EOM >$R/boot/config.txt
kernel=uboot.bin
EOM

    # Set up firmware config : WARNING this is /boot/!
    cat <<EOM >$R/boot/cmdline.txt
net.ifnames=0 biosdevname=0 dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=${FS} elevator=deadline rootwait quiet splash
EOM
}

function clean_up() {
    rm -f $R/etc/apt/*.save || true
    rm -f $R/etc/apt/sources.list.d/*.save || true
    rm -f $R/etc/resolvconf/resolv.conf.d/original
    rm -f $R/run/*/*pid || true
    rm -f $R/run/*pid || true
    rm -f $R/run/cups/cups.sock || true
    rm -f $R/run/uuidd/request || true
    rm -f $R/etc/*-
    rm -rf $R/tmp/*
    rm -f $R/var/crash/*
    rm -f $R/var/lib/urandom/random-seed

    # Clean up old Raspberry Pi firmware and modules
    rm -f $R/boot/.firmware_revision || true
    rm -rf $R/boot.bak || true
    rm -rf $R/lib/modules/4.1.7* || true
    rm -rf $R/lib/modules.bak || true

    # Potentially sensitive.
    rm -f $R/root/.bash_history
    rm -f $R/root/.ssh/known_hosts

    # Machine-specific, so remove in case this system is going to be
    # cloned.  These will be regenerated on the first boot.
    rm -f $R/etc/udev/rules.d/70-persistent-cd.rules
    rm -f $R/etc/udev/rules.d/70-persistent-net.rules
    rm -f $R/etc/NetworkManager/system-connections/*
    [ -L $R/var/lib/dbus/machine-id ] || rm -f $R/var/lib/dbus/machine-id
    echo '' > $R/etc/machine-id

    # Enable cofi
    if [ -e $R/etc/ld.so.preload.disable ]; then
        mv -v $R/etc/ld.so.preload.disable $R/etc/ld.so.preload
    fi

    rm -rf $R/tmp/.bootstrap || true
    rm -rf $R/tmp/.minimal || true
    rm -rf $R/tmp/.standard || true
}

function unarchive_base_image() {
    local BASE_IMAGE="${FLAVOUR}-${VERSION}${QUALITY}-armhf-base.tar.gz"
    local TARGET="${1}"
    if [ ! -d "${TARGET}" ]; then
        mkdir -p "${TARGET}"
    fi
    tar -xvzf "${PWD}/../${BASE_IMAGE}" -C ${TARGET} .
}

function single_stage_developer_rpi() {
    R="${BASE_R}"
    unarchive_base_image ${R}
    sync_to "${DEVICE_R}"
    R="${DEVICE_R}"
    mount_system

    create_groups
    create_user
    prepare_oem_config
    configure_ssh
    configure_network
    setup_developer_package
#    setup_kernel ${FS_TYPE}
#    setup_alternative_kernel ${FS_TYPE}
    setup_minimal_kernel ${FS_TYPE}
    apt_clean
    clean_up

    umount_system
}

single_stage_developer_rpi

