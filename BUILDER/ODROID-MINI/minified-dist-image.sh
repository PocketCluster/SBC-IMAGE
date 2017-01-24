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

    # SIZE_LIMIT -> (407 + 135) ~ 550 MB | SIZE -> 550 * 1024 * 1024 / 512 = 1126400     |  SEEK = SIZE_LIMIT * 1.1 = 600
    if [ ${GB} -eq 0 ]; then
        SIZE_LIMIT=550
        SIZE=1126400
        SEEK=600
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
    rsync -a "$R/" "${MOUNTDIR}/"
    umount -l "${MOUNTDIR}"
    losetup -d "${ROOT_LOOP}"
    losetup -d "${BOOT_LOOP}"

    # Copying the original bootloader
    TOP_LOOP="$(losetup -o 0 --sizelimit $((264192 * 512)) -f --show ${BASEDIR}/${IMAGE})"
    dd if=${PWD}/../CAPTURED-BOOT/ODROID/BOOTLOADER-C2-3.14.79-102-20170125.img of=${TOP_LOOP} bs=512 count=264192
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
make_tarball
