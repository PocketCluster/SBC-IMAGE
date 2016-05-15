#!/bin/sh

########################################################################
# rpi2-build-image
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

set -e
set -x

RELEASE=trusty
BASEDIR=${PWD}/${RELEASE}
BUILDDIR=${BASEDIR}/build
# I use a local caching proxy to save time/bandwidth; in this mode, the
# local mirror is used to download almost everything, then the standard
# http://ports.ubuntu.com/ is replaced at the end for distribution.
#LOCAL_MIRROR=""

# Don't clobber an old build
if [ -e "$BUILDDIR" ]; then
  echo "$BUILDDIR exists, not proceeding"
  exit 1
fi

# Set up environment
export TZ=UTC
R=${BUILDDIR}/chroot
mkdir -p $R

# Base debootstrap
apt-get -y install ubuntu-keyring
if [ -n "$LOCAL_MIRROR" ]; then
  debootstrap $RELEASE $R $LOCAL_MIRROR
else
  debootstrap $RELEASE $R http://ports.ubuntu.com/
fi

# Mount required filesystems
mount -t proc none $R/proc
mount -t sysfs none $R/sys

# Set up initial sources.list
if [ -n "$LOCAL_MIRROR" ]; then
  cat <<EOM >$R/etc/apt/sources.list
deb ${LOCAL_MIRROR} ${RELEASE} main restricted universe multiverse
# deb-src ${LOCAL_MIRROR} ${RELEASE} main restricted universe multiverse

deb ${LOCAL_MIRROR} ${RELEASE}-updates main restricted universe multiverse
# deb-src ${LOCAL_MIRROR} ${RELEASE}-updates main restricted universe multiverse

deb ${LOCAL_MIRROR} ${RELEASE}-security main restricted universe multiverse
# deb-src ${LOCAL_MIRROR} ${RELEASE}-security main restricted universe multiverse

deb ${LOCAL_MIRROR} ${RELEASE}-backports main restricted universe multiverse
# deb-src ${LOCAL_MIRROR} ${RELEASE}-backports main restricted universe multiverse
EOM
else
  cat <<EOM >$R/etc/apt/sources.list
deb http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
EOM
fi

wget -q -O- "http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0x4759FA960E27C0A6" | chroot $R apt-key add -
chroot $R apt-get update
chroot $R apt-get -y -u dist-upgrade

# Install the RPi PPA
cat <<"EOM" >$R/etc/apt/preferences.d/rpi2-ppa
Package: *
Pin: release o=LP-PPA-fo0bar-rpi2
Pin-Priority: 990

Package: *
Pin: release o=LP-PPA-fo0bar-rpi2-staging
Pin-Priority: 990
EOM
chroot $R apt-get -y install software-properties-common ubuntu-keyring
chroot $R apt-add-repository -y ppa:fo0bar/rpi2
chroot $R apt-get update

# Standard packages
chroot $R apt-get -y install ubuntu-standard initramfs-tools raspberrypi-bootloader-nokernel rpi2-ubuntu-errata language-pack-en

# Kernel installation
# Install flash-kernel last so it doesn't try (and fail) to detect the
# platform in the chroot.
chroot $R apt-get -y --no-install-recommends install linux-image-rpi2
chroot $R apt-get -y install flash-kernel
VMLINUZ="$(ls -1 $R/boot/vmlinuz-* | sort | tail -n 1)"
[ -z "$VMLINUZ" ] && exit 1
cp $VMLINUZ $R/boot/firmware/kernel7.img
INITRD="$(ls -1 $R/boot/initrd.img-* | sort | tail -n 1)"
[ -z "$INITRD" ] && exit 1
cp $INITRD $R/boot/firmware/initrd7.img

# 2016-03-26 WE ARE UPDATING FILES FROM RASPIBIAN
rm -rf ${R}/boot/firmware/*
rsync -avz ${PWD}/rasp-firmware-03-26-2016/* ${R}/boot/firmware/
chmod -R 644 ${R}/boot/firmware/*

# Install video drivers
chroot $R apt-get -y install libraspberrypi0 libraspberrypi-bin \
libraspberrypi-bin-nonfree

# Create sym-links to VideoCore utilities for 3rd party script
# compatibility.
mkdir -p ${R}/opt/vc/bin
mkdir -p ${R}/opt/vc/sbin
for FILE in containers_check_frame_int \
            containers_datagram_receiver \
            containers_datagram_sender \
            containers_dump_pktfile \
            containers_rtp_decoder \
            containers_stream_client \
            containers_stream_server \
            containers_test \
            containers_test_bits \
            containers_test_uri \
            containers_uri_pipe \
            edidparser \
            mmal_vc_diag \
            raspistill \
            raspivid \
            raspividyuv \
            raspiyuv \
            tvservice \
            vcdbg \
            vcgencmd \
            vchiq_test \
            vcsmem; do
    chroot $R ln -s /usr/bin/${FILE} /opt/vc/bin/
done
chroot $R ln -s /usr/sbin/vcfiled /opt/vc/sbin/

# Set up fstab
cat <<EOM >$R/etc/fstab
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1
/dev/mmcblk0p1  /boot/firmware  vfat    defaults          0       2
EOM

# Set up hosts
echo rpi-node >$R/etc/hostname
cat <<EOM >$R/etc/hosts
127.0.0.1       localhost
# ::1             localhost ip6-localhost ip6-loopback
# ff02::1         ip6-allnodes
# ff02::2         ip6-allrouters

127.0.0.1       rpi-node
EOM

# Set up default user
chroot $R adduser --gecos "Pocket Cluster User" --add_extra_groups --disabled-password pocket
chroot $R usermod -a -G sudo,adm -p $(echo "pocket" | openssl passwd -1 -stdin) pocket
echo "pocket ALL=(ALL) NOPASSWD:ALL" | tee "${R}/etc/sudoers.d/pocket"

# Restore standard sources.list if a local mirror was used
if [ -n "$LOCAL_MIRROR" ]; then
  cat <<EOM >$R/etc/apt/sources.list
deb http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
EOM
chroot $R apt-get update
fi

# add pocketcluster repo
# echo "deb http://dist.pocketcluster.io/ ${RELEASE} main" | tee "${R}/etc/apt/sources.list.d/pocketcluster.list"
# chroot $R apt-key adv --keyserver keys.gnupg.net --recv-keys 2AF8E5BF

# install salt-minion
echo "deb http://ppa.launchpad.net/saltstack/salt/ubuntu ${RELEASE} main" | tee "${R}/etc/apt/sources.list.d/saltstack.list"
wget -q -O- "http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0x4759FA960E27C0A6" | chroot $R apt-key add -

chroot $R apt-get update
chroot $R apt-get -y install build-essential python2.7-dev python-pip python2.7-examples salt-minion openssh-server dphys-swapfile

#chroot $R update-rc.d dphys-swapfile start 20 2 3 4 5 . stop 10 0 1 6 .
chroot $R update-rc.d -f dphys-swapfile remove

# Clean cached downloads
chroot $R apt-get clean

# Set up interfaces
cat <<EOM >$R/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet dhcp
EOM

# Set up firmware config
cat <<EOM >$R/boot/firmware/config.txt
# For more options and information see 
# http://www.raspberrypi.org/documentation/configuration/config-txt.md
# Some settings may impact device functionality. See link above for details

# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
#disable_overscan=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800

# Uncomment some or all of these to enable the optional hardware interfaces
#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

# Uncomment this to enable the lirc-rpi module
#dtoverlay=lirc-rpi

# Additional overlays and parameters are documented /boot/overlays/README

# Enable audio (loads snd_bcm2835)
#dtparam=audio=on
EOM

ln -sf firmware/config.txt $R/boot/config.txt
echo 'dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootwait' > $R/boot/firmware/cmdline.txt
ln -sf firmware/cmdline.txt $R/boot/cmdline.txt

# Load sound module on boot
cat <<EOM >$R/lib/modules-load.d/rpi2.conf
# snd_bcm2835
# bcm2708_rng
EOM

# Blacklist platform modules not applicable to the RPi2
cat <<EOM >$R/etc/modprobe.d/rpi2.conf
blacklist snd_soc_pcm512x_i2c
blacklist snd_soc_pcm512x
blacklist snd_soc_tas5713
blacklist snd_soc_wm8804
EOM

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

# Setup Default SwapFile
sed -i 's|#CONF_|CONF_|g' $R/etc/dphys-swapfile
sed -i 's|CONF_SWAPSIZE=[0-9]*|CONF_SWAPSIZE=2048|g' $R/etc/dphys-swapfile
sed -i 's|CONF_SWAPFACTOR=[0-9]*|CONF_SWAPFACTOR=2|g' $R/etc/dphys-swapfile
sed -i 's|CONF_MAXSWAP=[0-9]*|CONF_MAXSWAP=2048|g' $R/etc/dphys-swapfile

# Setup PocketD 
chroot $R pip install bson netifaces six
mkdir -p $R/opt/pocket-1.0.0/bin
chroot $R ln -s /opt/pocket-1.0.0 /opt/pocket
cp ${PWD}/pocketd/pocket $R/etc/init.d/
cp ${PWD}/pocketd/main $R/opt/pocket-1.0.0/bin/
# chroot $R update-rc.d pocket start 90 2 3 4 5 . stop 10 0 1 6 .
chroot $R update-rc.d pocket defaults 90 10
chroot $R update-rc.d pocket enable
# you need at least once start/stop a service for it to automatically start
chroot $R service pocket start
chroot $R service pocket stop
rm -rf $R/etc/pocket

#create top pocket, bigpkg directory
mkdir -p $R/pocket
mkdir -p $R/bigpkg
POCKET_UID=$(chroot $R id -u pocket)
POCKET_GID=$(chroot $R id -g pocket)
chown -R ${POCKET_UID}:${POCKET_GID} $R/pocket
chown -R ${POCKET_UID}:${POCKET_GID} $R/bigpkg
#chroot $R bash -c "chown -R pocket:pocket $R/pocket"
#chroot $R bash -c "chown -R pocket:pocket $R/bigpkg"

# repartition and swap activator
cp ${PWD}/repartition.sh $R/
cp ${PWD}/makefsswap.sh $R/

chmod 500 $R/makefsswap.sh
chmod 500 $R/repartition.sh

# Unmount mounted filesystems
umount $R/proc
umount $R/sys

# Clean up files
rm -f $R/etc/apt/sources.list.save
rm -f $R/etc/resolvconf/resolv.conf.d/original
rm -rf $R/run
mkdir -p $R/run
rm -f $R/etc/*-
rm -f $R/root/.bash_history
rm -rf $R/tmp/*
rm -f $R/var/lib/urandom/random-seed
[ -L $R/var/lib/dbus/machine-id ] || rm -f $R/var/lib/dbus/machine-id
rm -f $R/etc/machine-id

# Build the image file
# block size calculation:  1025 MB * 1024 * 1024 / 512 = 2099200

DATE="$(date +%Y-%m-%d)"
dd if=/dev/zero of="$BASEDIR/${DATE}-ubuntu-${RELEASE}.img" bs=1M count=1
dd if=/dev/zero of="$BASEDIR/${DATE}-ubuntu-${RELEASE}.img" bs=1M count=0 seek=1090
sfdisk -f "$BASEDIR/${DATE}-ubuntu-${RELEASE}.img" <<EOM
unit: sectors

1 : start=     2048, size=   131072, Id= c, bootable
2 : start=   133120, size=  2099200, Id=83
3 : start=        0, size=        0, Id= 0
4 : start=        0, size=        0, Id= 0
EOM
VFAT_LOOP="$(losetup -o 1M --sizelimit 64M -f --show $BASEDIR/${DATE}-ubuntu-${RELEASE}.img)"
EXT4_LOOP="$(losetup -o 65M --sizelimit 1025M -f --show $BASEDIR/${DATE}-ubuntu-${RELEASE}.img)"
mkfs.vfat "$VFAT_LOOP"
mkfs.ext4 "$EXT4_LOOP"
MOUNTDIR="$BUILDDIR/mount"
mkdir -p "$MOUNTDIR"
mount "$EXT4_LOOP" "$MOUNTDIR"
mkdir -p "$MOUNTDIR/boot/firmware"
mount "$VFAT_LOOP" "$MOUNTDIR/boot/firmware"
rsync -a "$R/" "$MOUNTDIR/"
umount "$MOUNTDIR/boot/firmware"
umount "$MOUNTDIR"
losetup -d "$EXT4_LOOP"
losetup -d "$VFAT_LOOP"
if which bmaptool; then
  bmaptool create -o "$BASEDIR/${DATE}-ubuntu-${RELEASE}.bmap" "$BASEDIR/${DATE}-ubuntu-${RELEASE}.img"
fi

# Done!
