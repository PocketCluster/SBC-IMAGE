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


# Base debootstrap
function bootstrap() {
    # Required tools
    apt-get -y install binfmt-support debootstrap f2fs-tools qemu-user-static rsync ubuntu-keyring wget whois
    update-binfmts --enable qemu-${DEVICE_ARCH}

    # Use the same base system for all flavours.
    if [ ! -f "${R}/tmp/.bootstrap" ]; then
        if [ "${ARCH}" == "${DEVICE_ARCH}" ]; then
            debootstrap --variant=minbase --verbose $RELEASE $R http://ports.ubuntu.com/
        else
            qemu-debootstrap --variant=minbase --verbose --arch=arm64 $RELEASE $R http://ports.ubuntu.com/
        fi
        touch "$R/tmp/.bootstrap"
    fi
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

# Install Ubuntu Tiny
function ubunty_tiny() {
    # Basic Packages
    chroot $R apt-get -y install language-pack-en-base f2fs-tools software-properties-common u-boot-tools isc-dhcp-client udev netbase ifupdown iproute iputils-ping wget net-tools wpasupplicant ntpdate ntp less tzdata console-common nano 
    # Config timezone, Keyboard, Console
    chroot $R dpkg-reconfigure --frontend=noninteractive tzdata
    # chroot $R dpkg-reconfigure --frontend=noninteractive keyboard-configuration
    # chroot $R apt-get -y install console-data
    # chroot $R dpkg-reconfigure --frontend=noninteractive console-setup
}

function apt_clean() {
    chroot $R apt-get -y autoremove
    chroot $R apt-get clean
}

function make_archive() {
    local BASE_IMAGE="${FLAVOUR}-${VERSION}${QUALITY}-arm64-base.tar.gz"
    tar -czf "${BASEDIR}/${BASE_IMAGE}" -C $R .
}

function build-base() {
    R="${BASE_R}"
    bootstrap
    mount_system

    generate_locale
    apt_sources
    apt_update_only
    ubunty_tiny
    apt_clean

    umount_system
    make_archive
}

build-base
