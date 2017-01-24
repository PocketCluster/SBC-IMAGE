#!/usr/bin/env bash

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
    rm -rf ${PWD}/C2
}

clean_residue

