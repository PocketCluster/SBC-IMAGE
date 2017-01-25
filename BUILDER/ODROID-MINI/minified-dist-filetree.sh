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

if [ -f minified-settings.sh ]; then
    source minified-settings.sh
else
    echo "ERROR! Could not source build-settings.sh."
    exit 1
fi

if [ $(id -u) -ne 0 ]; then
    echo "ERROR! Must be root."
    exit 1
fi

# Base debootstrap
function check_crossbuild_req() {
    # Required tools
    if [ ${ARCH} != ${DEVICE_ARCH} ]; then
        apt-get -y install binfmt-support debootstrap f2fs-tools qemu-user-static rsync ubuntu-keyring wget whois
        update-binfmts --enable qemu-${DEVICE_ARCH}
    fi
}

function unarchive_base_image() {
    local BASE_IMAGE="${RELEASE}-base-arm64.tar.gz"
    local TARGET="${1}"
    if [ ! -d "${TARGET}" ]; then
        mkdir -p "${TARGET}"
    fi
    tar -xvzf "${PWD}/../${BASE_IMAGE}" -C ${TARGET}
}

function sync_to() {
    local TARGET="${1}"
    if [ ! -d "${TARGET}" ]; then
        mkdir -p "${TARGET}"
    fi
    #rsync -a --progress --delete ${R}/ ${TARGET}/
    rsync -a --delete ${R}/ ${TARGET}/
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

    cat <<EOM >$R/etc/apt/apt.conf.d/50singleboards
# Never use pdiffs, current implementation is very slow on low-powered devices
Acquire::PDiffs "0";
EOM
}

function apt_block_suggestion() {
    mkdir -p $R/etc/apt/
    cat <<EOM >$R/etc/apt/apt.conf
# APT::Install-Recommends "false";
APT::Get::Install-Suggests "false";
APT::Install-Suggests "false";
EOM
}

function apt_update_only() {
    chroot $R apt-get update
}

# Install Ubuntu Essentials
function ubuntu_essential() {
    # only the essentials
    chroot $R apt-get -y install language-pack-en-base ca-certificates isc-dhcp-client udev netbase ifupdown iproute iputils-ping net-tools ntpdate ntp tzdata dialog resolvconf
    # Config timezone, Keyboard, Console
    chroot $R dpkg-reconfigure --frontend=noninteractive tzdata
    chroot $R dpkg-reconfigure --frontend=noninteractive debconf

    # console & keyboard
    chroot $R apt-get -y install console-common console-data console-setup keyboard-configuration
    chroot $R dpkg-reconfigure --frontend=noninteractive keyboard-configuration
    chroot $R dpkg-reconfigure --frontend=noninteractive console-setup

    # system hang prevention
    chroot $R apt-get -y install libpam-systemd dbus
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

    # Doesn't work ;(
    #cp -Rf $R/usr/share/locale/en* $R/tmp/
    #rm -rf $R/usr/share/locale/*
    #mv $R/tmp/en* $R/usr/share/locale/

    for LOCALE in $(chroot $R locale | cut -d'=' -f2 | grep -v : | sed 's/"//g' | uniq); do
        if [ -n "${LOCALE}" ]; then
            chroot $R locale-gen $LOCALE
            chroot $R update-locale LC_ALL=$LOCALE
        fi
    done
    chroot $R dpkg-reconfigure --frontend=noninteractive locales
}

function docker_setup() {
    # docker dependencies
    chroot $R apt-get -y install apparmor adduser iptables init-system-helpers lsb-base libapparmor1 libc6 libdevmapper1.02.1 
    # docker recommends
    chroot $R apt-get -y install cgroupfs-mount cgroup-lite git xz-utils
    # docker suggestion
    chroot $R apt-get -y install btrfs-tools
    # docker possible utility
    chroot $R apt-get -y install apparmor-profiles apparmor-utils bridge-utils

    # aufs is blocked for now as not in mainstream yet 4.9 maybe?
    # chroot $R apt-get -y install aufs-tools

    # install docker
    mkdir -p $R/tmp/
    cp ${PWD}/docker.io_1.10.3-0ubuntu6_arm64.deb $R/tmp
    chroot $R dpkg -i /tmp/docker.io_1.10.3-0ubuntu6_arm64.deb
    rm -rf $R/tmp/docker.io_1.10.3-0ubuntu6_arm64.deb || true

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
    chroot $R usermod -a -G sudo -p ${PASSWD} ${DIST_USERNAME}
}

function setup_odroid_specifics() {
    # /lib/firmware/3.14.79-102
    mkdir -p $R/lib/firmware/
    tar -xzf ../CAPTURED-BOOT/ODROID/odroid-firmware-3.14.79-102.tar.gz -C $R/lib/firmware/

    # /lib/modules/3.14.79-102
    mkdir -p $R/lib/modules/
    tar -xzf ../CAPTURED-BOOT/ODROID/odroid-modules-3.14.79-102.tar.gz -C $R/lib/modules/
    
    # /boot directory
    tar -xzf ../CAPTURED-BOOT/ODROID/BOOTDIR-C2-3.14.79-102-20170125.tar.gz -C $R/

    cat <<EOM >$R/etc/fstab
UUID=${FS_ROOT_UUID} / ext4 errors=remount-ro,noatime 0 1
EOM
}

function apt_clean() {
    chroot $R apt-get -y autoremove --purge
    chroot $R apt-get clean
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

    # clean up locales and apt cache
    rm -rf $R/var/cache/debconf/*-old
    rm -rf $R/var/lib/apt/lists/*
    rm -rf $R/usr/share/doc/*

    # remove logs as well.
    rm -rf $R/var/log/*

    # Clean up old firmware and modules
    rm -f $R/boot/.firmware_revision || true
    rm -rf $R/boot.bak || true

    # non-existent at this point
    #rm -rf $R/lib/modules/4.1.7* || true
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

function single_stage_odroid() {
    R="${BASE_R}"
    #check_crossbuild_req
    unarchive_base_image ${R}
    sync_to "${DEVICE_R}"

    R="${DEVICE_R}"
    mount_system
    configure_network
    apt_sources
    apt_block_suggestion
    apt_update_only
    ubuntu_essential
    generate_locale
    docker_setup

    create_groups
    create_user
    
    setup_odroid_specifics
    apt_clean
    clean_up
    umount_system
}

single_stage_odroid
