#!/usr/bin/env bash

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

# Unmount host system
function umount_system() {
    umount -l $R/sys
    umount -l $R/proc
    umount -l $R/dev/pts
    umount -l $R/dev
    echo "" > $R/etc/resolv.conf
}

function clean_residue() {
    R="${DEVICE_R}"
    #mount_system
    umount_system

    rm -rf ${BASE_R}
    rm -rf ${DEVICE_R}
    rm -rf ${PWD}/PINE64
}

clean_residue
