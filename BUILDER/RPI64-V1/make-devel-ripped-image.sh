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

TARBALL="${DIST_NAME}-devel-arm64-raspberry-rootfs-${RELEASE}.tar.bz2"
IMAGE="${DIST_NAME}-devel-arm64-raspberry-${RELEASE}.img"

function make_raspi2_image() {
    # Build the image file
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    # SIZE_LIMIT -> (1100 + 200M) ~ 1400 MB | SIZE -> 1500 * 1024 * 1024 / 512 = 2867200 |  SEEK = SIZE_LIMIT * 1.2 = 1680
    SIZE_LIMIT=1400
    SIZE=2867200
    SEEK=1680

    # If a compress version exists, remove it.
    rm -f "${BASEDIR}/${IMAGE}.bz2" || true

    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=1
    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=0 seek=${SEEK}

    # Copying the original bootloader
    TOP_LOOP="$(losetup -o 0 --sizelimit $((411652 * 512)) -f --show ${BASEDIR}/${IMAGE})"
    dd if=${PWD}/../CAPTURED-BOOT/RPI64/BOOTLOADER-RPI64-OSUSE-Leap42.2-20170806.img of=${TOP_LOOP} bs=512 count=411652
    losetup -d "${TOP_LOOP}"

    # !!! this is the actual size of rootfs partition (we need to count the last sector as well with + 1) !!!
    ROOT_SIZE=$((${SIZE} - 413696 + 1))
    echo "ROOT_FS_SIZE is ${ROOT_SIZE}"

    sfdisk -f "$BASEDIR/${IMAGE}" <<EOM
unit: sectors

1 : start=     2048, size=   409604, Id= c, bootable
2 : start=   413696, size=  ${ROOT_SIZE}, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOM

    ### CHECK EXACT START SECTOR & SECTOR SIZE
    ROOT_LOOP="$(losetup --offset $((413696 * 512)) --sizelimit $((${ROOT_SIZE} * 512)) -f --show ${BASEDIR}/${IMAGE})"    
    # https://blogofterje.wordpress.com/2012/01/14/optimizing-fs-on-sd-card/
    mkfs.ext4 -F -O ^has_journal -E stride=2,stripe-width=1024 -b 4096 -L PC_ROOT -U ${FS_ROOT_UUID} -m 5 "${ROOT_LOOP}"
    MOUNTDIR="${BUILDDIR}/mount"
    mkdir -p "${MOUNTDIR}"
    mount "${ROOT_LOOP}" "${MOUNTDIR}"
    rsync -a --progress "$R/" "${MOUNTDIR}/"
    umount -l "${MOUNTDIR}"
    losetup -d "${ROOT_LOOP}"
}

function make_tarball() {
    if [ ${MAKE_TARBALL} -eq 1 ]; then
        rm -f "${BASEDIR}/${TARBALL}" || true
        tar -cSf "${BASEDIR}/${TARBALL}" $R
    fi
}

R=${DEVICE_R}
make_raspi2_image ${FS_TYPE} 0

