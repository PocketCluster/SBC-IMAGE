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

function make_odroidc2_image() {
    # Build the image file
    local FS="${1}"
    local GB=${2}

    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    if [ ${GB} -ne 0 ] && [ ${GB} -ne 1 ]; then
        echo "ERROR! Unsupport card image size requested. Exitting."
        exit 1
    fi

    # SIZE_LIMIT -> 700 MB * 1024 * 1024 / 512 = SIZE 1433600 | SEEK = SIZE_LIMIT + 65
    if [ ${GB} -eq 0 ]; then
        SEEK=830
        SIZE=1433600
        SIZE_LIMIT=700

    # SIZE_LIMIT -> 1280 MB * 1024 * 1024 / 512 = SIZE 2621440 | SEEK = SIZE_LIMIT + 65
    elif [ ${GB} -eq 1 ]; then
        SEEK=1448
        SIZE=2621440
        SIZE_LIMIT=1280
    fi

    # If a compress version exists, remove it.
    rm -f "${BASEDIR}/${IMAGE}.bz2" || true

    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=1
    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=0 seek=${SEEK}

    sfdisk -f "$BASEDIR/${IMAGE}" <<EOM
unit: sectors

1 : start=     2048, size=   262144, Id= c, bootable
2 : start=   264192, size=  ${SIZE}, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOM

    BOOT_LOOP="$(losetup -o $((2048 * 512)) --sizelimit $((262144 * 512)) -f --show ${BASEDIR}/${IMAGE})"
    ROOT_LOOP="$(losetup -o $((264192 * 512)) -f --show ${BASEDIR}/${IMAGE})"

    # make filesystem
    mkfs.vfat -n PC_BOOT -S 512 -s 16 -v "${BOOT_LOOP}"
    if [ "${FS}" == "ext4" ]; then
        mkfs.ext4 -O ^has_journal -b 4096 -L PC_ROOT -U e139ce78-9841-40fe-8823-96a304a09859 -m 0 "${ROOT_LOOP}" 
    else
        mkfs.f2fs -l PC_ROOT -o 1 "${ROOT_LOOP}"
    fi

    MOUNTDIR="${BUILDDIR}/mount"
    mkdir -p "${MOUNTDIR}"
    mount "${ROOT_LOOP}" "${MOUNTDIR}"
    mkdir -p "${MOUNTDIR}/boot"
    mount "${BOOT_LOOP}" "${MOUNTDIR}/boot"
    rsync -a --progress "$R/" "${MOUNTDIR}/"
    umount -l "${MOUNTDIR}/boot"
    umount -l "${MOUNTDIR}"
    losetup -d "${ROOT_LOOP}"
    losetup -d "${BOOT_LOOP}"

    # Copying the original bootloader
    TOP_LOOP="$(losetup -o 0 --sizelimit $((264192 * 512)) -f --show ${BASEDIR}/${IMAGE})"
    dd if=${PWD}/../BOOTLOADER-C2-3.14.29-56.img of=${TOP_LOOP} bs=512 count=264192
    losetup -d "${TOP_LOOP}"
}

function make_tarball() {
    if [ ${MAKE_TARBALL} -eq 1 ]; then
        rm -f "${BASEDIR}/${TARBALL}" || true
        tar -cSf "${BASEDIR}/${TARBALL}" $R
    fi
}

R=${DEVICE_R}
make_odroidc2_image ${FS_TYPE} 0
