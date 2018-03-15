#!/usr/bin/env bash

# Linux Kernel 4.9.40
export FIRMWARE_COMMIT="3202f1b16896029f9da1b074b0912177e8960b52"
export FIMRWARE_REPO="rpi-firmware"
export RPI_BOOT="RPIROOT/boot"
export RPI_LIB="RPIROOT/lib"

# checkout firmware
pushd ${PWD}
git clone -b master https://github.com/Hexxeh/rpi-firmware && cd ${FIMRWARE_REPO} && git checkout ${FIRMWARE_COMMIT}
popd

# setup directories
mkdir -p {${RPI_BOOT},${RPI_LIB}}

# save modules
mv ${FIMRWARE_REPO}/modules ${RPI_LIB}

# save overlays
mv ${FIMRWARE_REPO}/overlays ${RPI_BOOT}

# save bootfiles
mv ${FIMRWARE_REPO}/COPYING.linux     ${RPI_BOOT}
mv ${FIMRWARE_REPO}/LICENCE.broadcom  ${RPI_BOOT}
mv ${FIMRWARE_REPO}/*.dtb             ${RPI_BOOT}
mv ${FIMRWARE_REPO}/*.bin             ${RPI_BOOT}
mv ${FIMRWARE_REPO}/*.dat             ${RPI_BOOT}
mv ${FIMRWARE_REPO}/*.img             ${RPI_BOOT}
mv ${FIMRWARE_REPO}/*.elf             ${RPI_BOOT}

pushd ${PWD}
cd RPIROOT && tar cvzf ../bootstrap-4.9.40.tar.gz *
popd
