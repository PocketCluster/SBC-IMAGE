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

TARBALL="${DIST_NAME}-devel-armhf-raspberry-rootfs-${RELEASE}.tar.bz2"
IMAGE="${DIST_NAME}-devel-armhf-raspberry-${RELEASE}.img"

function make_raspi2_image() {
    # Build the image file
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    # SIZE_LIMIT -> (978M + 64M) ~ 1050 MB | SIZE -> 610 * 1024 * 1024 / 512 = 2150400 |  SEEK = SIZE_LIMIT * 1.1 = 1155
    SIZE_LIMIT=1050
    SIZE=2150400
    SEEK=1155

    # If a compress version exists, remove it.
    rm -f "${BASEDIR}/${IMAGE}.bz2" || true

    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=1
    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=1M count=0 seek=${SEEK}

    sfdisk -f "$BASEDIR/${IMAGE}" <<EOM
unit: sectors

1 : start=     2048, size=   131072, Id= c, bootable
2 : start=   133120, size=  ${SIZE}, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOM

    BOOT_LOOP="$(losetup -o 1M --sizelimit 64M -f --show ${BASEDIR}/${IMAGE})"
    ROOT_LOOP="$(losetup -o 65M --sizelimit ${SIZE_LIMIT}M -f --show ${BASEDIR}/${IMAGE})"
    mkfs.vfat -n PC_BOOT -S 512 -s 16 -v "${BOOT_LOOP}"
    if [ "${FS}" == "ext4" ]; then
        # https://blogofterje.wordpress.com/2012/01/14/optimizing-fs-on-sd-card/
        mkfs.ext4 -F -O ^has_journal -E stride=2,stripe-width=1024 -b 4096 -L PC_ROOT -U ${FS_ROOT_UUID} -m 5 "${ROOT_LOOP}"
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
}

function make_tarball() {
    if [ ${MAKE_TARBALL} -eq 1 ]; then
        rm -f "${BASEDIR}/${TARBALL}" || true
        tar -cSf "${BASEDIR}/${TARBALL}" $R
    fi
}

R=${DEVICE_R}
make_raspi2_image ${FS_TYPE} 0

