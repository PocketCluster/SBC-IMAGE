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

TARBALL="${DIST_NAME}-devel-arm64-pine64-rootfs-${RELEASE}.tar.bz2"
IMAGE="${DIST_NAME}-devel-arm64-pine64-${RELEASE}.img"

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

function make_pine64_image() {
    # Build the image file
    local FS="${1}"

    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    # SIZE_LIMIT -> (586 + 70) ~ 660 MB | SIZE -> 660 * 1024 * 1024 / 512 = 1351680     |  SEEK = SIZE_LIMIT * 1.1 = 726
    SIZE_LIMIT=660
    SIZE=1351680
    SEEK=726

    # If a compress version exists, remove it.
    rm -f "${BASEDIR}/${IMAGE}.bz2" || true

    # Create a loop image
    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=1
    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=0 seek=${SEEK}

    # Copying the original bootloader
    TOP_LOOP="$(losetup -o 0 --sizelimit $((143360 * 512)) -f --show ${BASEDIR}/${IMAGE})"
    dd if=${PWD}/../CAPTURED-BOOT/PINE64/BOOTLOADER-PINE64-3.10.104-2017-01-30.img of=${TOP_LOOP} bs=512 count=143360
    losetup -d "${TOP_LOOP}"

    # Set disk partition
    sfdisk -f "$BASEDIR/${IMAGE}" <<EOM
unit: sectors

1 : start=    40960, size=   102400, Id= c, bootable
2 : start=   143360, size=  ${SIZE}, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOM

    # make root filesystem
    ROOT_LOOP="$(losetup -o $((143360 * 512)) -f --show ${BASEDIR}/${IMAGE})"
    # https://blogofterje.wordpress.com/2012/01/14/optimizing-fs-on-sd-card/
    mkfs.ext4 -F -O ^has_journal -E stride=2,stripe-width=1024 -b 4096 -L PC_ROOT -U ${FS_ROOT_UUID} -m 5 "${ROOT_LOOP}"
    MOUNTDIR="${BUILDDIR}/mount"
    mkdir -p "${MOUNTDIR}"
    mount "${ROOT_LOOP}" "${MOUNTDIR}"
    rsync -a "$R/" "${MOUNTDIR}/"
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
make_pine64_image ${FS_TYPE}
#make_tarball
