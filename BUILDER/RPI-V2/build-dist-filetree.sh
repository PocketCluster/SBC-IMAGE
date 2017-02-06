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

function unarchive_base_image() {
    local BASE_IMAGE="${RELEASE}-base-${DEVICE_ARCH}.tar.gz"
    local TARGET="${1}"
    if [ ! -d "${TARGET}" ]; then
        mkdir -p "${TARGET}"
    fi
    tar -xvzf "${PWD}/../${BASE_IMAGE}" -C ${TARGET}
}

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
}

function configure_network() {
    # Set up hosts
    echo ${DIST_HOSTNAME} >$R/etc/hostname
    echo "nameserver 8.8.8.8" > $R/etc/resolv.conf
    cat <<EOM >$R/etc/hosts
127.0.0.1       localhost
# ::1             localhost ip6-localhost ip6-loopback
# ff02::1         ip6-allnodes
# ff02::2         ip6-allrouters

127.0.1.1       ${DIST_HOSTNAME}
EOM

    mkdir -p $R/etc/network
    chroot $R chown -R root:root /etc/network

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
}

function apt_setup() {
    # Tell DPKG not to install documents
    if [ ! -d "${R}/etc/dpkg/dpkg.cfg.d/" ]; then
        mkdir ${R}/etc/dpkg/dpkg.cfg.d/
    fi
    cat <<EOM >${R}/etc/dpkg/dpkg.cfg.d/01_nodoc
path-exclude /usr/share/doc/*
# we need to keep copyright files for legal reasons
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
# lintian stuff is small, but really unnecessary
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
# don't autocomplete
path-exclude /usr/share/zsh/vendor-completions/*
path-exclude /usr/share/bash-completion/completions/*
# don't install translation
path-exclude /usr/share/locale/*
path-include /usr/share/locale/en*
EOM

    # tell APT not to install recommends & suggestion
    if [ ! -d "${R}/etc/apt/apt.conf.d/" ]; then
        mkdir ${R}/etc/apt/apt.conf.d/
    fi
    cat <<EOM >$R/etc/apt/sources.list
deb http://ports.ubuntu.com/ ${RELEASE} main restricted universe
deb http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe
deb http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe
EOM
    cat <<EOM >${R}/etc/apt/apt.conf.d/50singleboards
# Never use pdiffs, current implementation is very slow on low-powered devices
Acquire::PDiffs "0";
EOM
    cat <<EOM >${R}/etc/apt/apt.conf
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOM

    chroot $R apt-get update
}

# Install Ubuntu Essentials
function ubuntu_essential() {
    # only the essentials
    chroot $R apt-get -y install --no-install-suggests language-pack-en-base ca-certificates isc-dhcp-client udev netbase ifupdown iproute iputils-ping net-tools ntpdate ntp tzdata dialog resolvconf
    # Config timezone, Keyboard, Console
    chroot $R dpkg-reconfigure --frontend=noninteractive tzdata
    chroot $R dpkg-reconfigure --frontend=noninteractive debconf

    # console & keyboard
    chroot $R apt-get -y install --no-install-suggests console-common console-data console-setup keyboard-configuration
    chroot $R dpkg-reconfigure --frontend=noninteractive keyboard-configuration
    chroot $R dpkg-reconfigure --frontend=noninteractive console-setup

    # system hang prevention
    chroot $R apt-get -y install --no-install-suggests libpam-systemd dbus
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

    cat <<EOM >${R}/etc/locale.gen
# This file lists locales that you wish to have built. You can find a list
# of valid supported locales at /usr/share/i18n/SUPPORTED, and you can add
# user defined locales to /usr/local/share/i18n/SUPPORTED. If you change
# this file, you need to rerun locale-gen.

en_US.UTF-8 UTF-8
EOM

    for LOCALE in $(chroot $R locale | cut -d'=' -f2 | grep -v : | sed 's/"//g' | uniq); do
        if [ -n "${LOCALE}" ]; then
            chroot $R locale-gen $LOCALE
            chroot $R update-locale LC_ALL=$LOCALE
        fi
    done

    chroot $R dpkg-reconfigure --frontend=noninteractive locales

    find ${R}/usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' | xargs rm -rf
}

function docker_setup() {
    # docker dependencies
    chroot $R apt-get -y install --no-install-suggests apparmor adduser iptables init-system-helpers lsb-base libapparmor1 libc6 libdevmapper1.02.1 
    # docker recommends
    chroot $R apt-get -y install --no-install-suggests cgroupfs-mount cgroup-lite git xz-utils
    # docker suggestion
    chroot $R apt-get -y install --no-install-suggests btrfs-tools
    # docker possible utility
    chroot $R apt-get -y install --no-install-suggests apparmor-profiles apparmor-utils bridge-utils

    # aufs is blocked for now as not in mainstream yet 4.9 maybe?
    # chroot $R apt-get -y install --no-install-suggests aufs-tools

    # install docker
    mkdir -p $R/tmp/
    cp ${PWD}/docker.io_1.10.3-0ubuntu6_armhf.deb $R/tmp
    chroot $R dpkg -i /tmp/docker.io_1.10.3-0ubuntu6_armhf.deb
    rm -rf $R/tmp/docker.io_1.10.3-0ubuntu6_armhf.deb || true

    echo "kernel.keys.root_maxkeys = 1000000" >> $R/etc/sysctl.conf
    chroot $R apt-mark hold u-boot-tools docker.io
}

function create_groups() {
    chroot $R groupadd -f --system input
    cat <<'EOM' >$R/usr/local/sbin/adduser.local
#!/bin/sh
# This script is executed as the final step when calling `adduser`
# USAGE:
#   adduser.local USER UID GID HOME

# Add user to general groups
usermod -a -G adm,input,video $1
EOM
    chmod +x $R/usr/local/sbin/adduser.local
}

# Create default user !!! This will be removed in release image as it will not properly create login profile for the real user. !!!
# Is this related to rc.local service???
function create_user() {
    local DIST_USERNAME="pocket"
    local DIST_USERGROUP="pocket"
    local DATE=$(date +%m%H%M%S)
    local PASSWD=$(mkpasswd -m sha-512 ${DIST_USERNAME} ${DATE})

    chroot $R addgroup --gid 29999 ${DIST_USERGROUP}
    chroot $R adduser --gecos "PocketCluster (temporary user)" --add_extra_groups --disabled-password --gid 29999 --uid 29999 ${DIST_USERNAME}
    chroot $R usermod -a -G sudo,docker -p ${PASSWD} ${DIST_USERNAME}
}

function setup_raspberry_specifics() {
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    # Hardware - Create a fake HW clock and add rng-tools These are coming from official repo
    chroot $R apt-get -y install fake-hwclock rng-tools
    
    # Bootloader installation
    cp ${PWD}/raspberrypi-bootloader_1.20160315-1~xenial1.0_armhf.deb $R/tmp
    chroot $R dpkg -i /tmp/raspberrypi-bootloader_1.20160315-1~xenial1.0_armhf.deb
    rm -rf $R/tmp/raspberrypi-bootloader_1.20160315-1~xenial1.0_armhf.deb || true
    # Remove all old modules
    rm -rf "${R}/lib/modules/*" || true
    
    # Firmware, Modules, Kernel 4.4.22-v7+
    chroot $R apt install -y --no-install-recommends --no-install-suggests curl binutils
    wget -c https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update -O $R/usr/bin/rpi-update
    chmod 755 $R/usr/bin/rpi-update
    chroot $R rpi-update d26c39bd353eb0ebbc7db3546277083eac4aa3bd
    rm $R/usr/bin/rpi-update
    # clear of tools
    chroot $R apt remove -y --purge curl binutils

    # Very minimal boot config
    #wget -c https://raw.githubusercontent.com/Evilpaul/RPi-config/master/config.txt -O $R/boot/config.txt
    cp ${PWD}/config.txt $R/boot/config.txt
    echo "net.ifnames=0 biosdevname=0 dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=${FS} elevator=deadline rootwait quiet splash" > $R/boot/cmdline.txt

    # Blacklist platform modules not applicable to the RPi2
    cat <<EOM >$R/etc/modprobe.d/blacklist-rpi.conf
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
blacklist brcmfmac
blacklist brcmutil
EOM

    # Set up fstab
    cat <<EOM >$R/etc/fstab
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ${FS}   defaults,noatime  0       1
/dev/mmcblk0p1  /boot/          vfat    defaults          0       2
EOM

    # udev rules
    printf 'SUBSYSTEM=="vchiq", GROUP="video", MODE="0660"\n' > $R/etc/udev/rules.d/10-local-rpi.rules
    printf 'SUBSYSTEM=="input", GROUP="input", MODE="0660"\n' >> $R/etc/udev/rules.d/99-com.rules

    # Save the clock
    chroot $R fake-hwclock save
}

function apt_clean() {
    chroot $R apt-get autoremove -y --purge
    chroot $R apt-get clean -y
    chroot $R apt-get autoclean -y 
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
    # slash rest of residue
    rm -rf $R/tmp/* 
    rm -rf $R/var/tmp/*
    rm -f $R/var/crash/*
    rm -f $R/var/lib/urandom/random-seed

    # clean up locales and apt cache
    rm -rf $R/var/cache/debconf/*-old
    rm -rf $R/var/lib/apt/lists/*
    rm -rf $R/var/lib/cache/*
    # remove logs as well.
    rm -rf $R/var/log/*

    # Remove apt cache indexes https://wiki.ubuntu.com/ReducingDiskFootprint
    # Apt stores two caches in /var/cache/apt/: srcpkgcache.bin is rather useless these days, and pkgcache.bin is only needed for faster lookups with apt-cache (software-center has its own cache). 
    # Removing those two buys 50 MB, for the price of apt-cache taking an extra two seconds for each lookup.
    rm -rf $R/var/cache/apt/pkgcache.bin || true
    rm -rf $R/var/cache/apt/srcpkgcache.bin || true

    # remove docs
    find ${R}/usr/share/doc -depth -type f ! -name copyright|xargs rm || true
    find ${R}/usr/share/doc -empty|xargs rmdir || true
    rm -rf ${R}/usr/share/man/* 
    rm -rf ${R}/usr/share/groff/* 
    rm -rf ${R}/usr/share/info/*
    rm -rf ${R}/usr/share/lintian/* 
    rm -rf ${R}/usr/share/linda/* 
    rm -rf ${R}/var/cache/man/*
    # remove auto-completion
    rm -rf ${R}/usr/share/zsh/vendor-completions/*
    rm -rf ${R}/usr/share/bash-completion/completions/*
    # then remove existing translations
    find ${R}/usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' | xargs rm -rf
    # make sure info directory is not broken for dep check
    mkdir -p ${R}/usr/share/info

    # Clean up old firmware and modules
    rm -f $R/boot/.firmware_revision || true
    rm -rf $R/boot.bak || true

    # Remove old modules
    echo "!!! ALWAYS CHECK IF OLD MODULE IS REMAINED !!!"
    rm -rf $R/lib/modules/4.1.19* || true
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

# Unmount host system
function umount_system() {
    umount -l $R/sys
    umount -l $R/proc
    umount -l $R/dev/pts
    umount -l $R/dev
}

function single_stage_build() {
    R="${DEVICE_R}"
    unarchive_base_image ${R}
    mount_system

    configure_network
    apt_setup
    ubuntu_essential
    generate_locale
    docker_setup

    create_groups
    create_user

    setup_raspberry_specifics ${FS_TYPE}
    apt_clean
    clean_up
    umount_system
}

single_stage_build
