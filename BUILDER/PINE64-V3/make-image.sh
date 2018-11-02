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

MOUNTDIR="${BUILDDIR}/mount"

TARBALL="${DIST_NAME}-devel-arm64-pine64-rootfs-${RELEASE}.tar.bz2"
IMAGE="${DIST_NAME}-devel-arm64-pine64-${RELEASE}.img"

SCSZ_WORKSPACE=$(cat /sys/block/sda/queue/hw_sector_size)
SCSZ_FILETREE=$(du -s -B ${SCSZ_WORKSPACE} ${DEVICE_R} | cut -f1)
TAIL_SPACE=$((100 * 1024 * 1024 / ${SCSZ_WORKSPACE})) # 100mb in sectors

echo "  File tree size is ${SCSZ_FILETREE} in sector"
echo "  /sys/block/sda/queue/hw_sector_size sector size is ${SCSZ_WORKSPACE}"
echo "  Tailing space is ${TAIL_SPACE}"

if [[ ! -d output ]]; then
    tar xzf bootstrap.tar.gz
fi

function make_pine64_image() {
    # Build the image file
    # SIZE_LIMIT -> (677 + 70) ~ 750 MB | SIZE -> 750 * 1024 * 1024 / 512 = 1536000     |  SEEK = SIZE_LIMIT * 1.1 = 820 (it should be 825. then it won't boot.)

    # 10mb for disk space
    SC_SIZE=$(( ${SCSZ_FILETREE} + ${TAIL_SPACE} ))

    # Create a loop image
    dd if=/dev/zero of="${BASEDIR}/${IMAGE}" bs=512 count=$((264192 + ${SC_SIZE}))

    # Set disk partition
    sfdisk -f "$BASEDIR/${IMAGE}" <<EOM
label: dos
unit: sectors

1 : start=     2048, size=     262144, Id=83, bootable
2 : start=   264192, size= ${SC_SIZE}, Id=83
3 : start=        0, size=          0, Id= 0
EOM

    XTARGET="$(losetup -f -P --show ${BASEDIR}/${IMAGE})"

    # creating filesystems
    mkfs.ext2 ${XTARGET}p1
    mkfs.ext4 ${XTARGET}p2

    # https://blogofterje.wordpress.com/2012/01/14/optimizing-fs-on-sd-card/
    #mkfs.ext4 -F -O ^has_journal -E stride=2,stripe-width=1024 -b 4096 -L PC_ROOT -U ${FS_ROOT_UUID} -m 5 "${ROOT_LOOP}"

    # setup rootfs
    mkdir -p ${MOUNTDIR}
    mount ${XTARGET}p2 ${MOUNTDIR}
    rsync -a "${DEVICE_R}/" "${MOUNTDIR}/"
    # copy modules
    rsync -a output/kernel/lib/modules/* ${MOUNTDIR}/lib/modules/
    rsync -a output/kernel/include/*     ${MOUNTDIR}/usr/src/linux-header-4.14.23arm64-dirty/

    # setup boot
    mount ${XTARGET}p1 ${MOUNTDIR}/boot
    cp -vf output/kernel/boot/Image ${MOUNTDIR}/boot/vmlinuz-4.14.23arm64-dirty
    cp -vf output/kernel/boot/System.map ${MOUNTDIR}/boot/System.map-4.14.23arm64-dirty
    cp -vf output/kernel/boot/config ${MOUNTDIR}/boot/config-4.14.23arm64-dirty
    cp -vf output/kernel/boot/dtb/sun50i-a64-pine64-plus.dtb ${MOUNTDIR}/boot/
    mkdir -p ${MOUNTDIR}/boot/extlinux
    cp -vf extlinux.conf ${MOUNTDIR}/boot/extlinux

    sync
    sync
    sync

    umount -l ${MOUNTDIR}/boot
    umount -l ${MOUNTDIR}
    umount -l ${XTARGET}* || :
    losetup -d ${XTARGET}

    dd conv=notrunc if=output/u-boot/u-boot-sunxi-image.spl of=${BASEDIR}/${IMAGE} bs=8k seek=1
}

function make_tarball() {
    if [ ${MAKE_TARBALL} -eq 1 ]; then
        rm -f "${BASEDIR}/${TARBALL}" || true
        tar -cSf "${BASEDIR}/${TARBALL}" $R
    fi
}

make_pine64_image
#make_tarball
