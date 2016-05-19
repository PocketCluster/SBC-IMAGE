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

# Mount host system
function mount_system() {
    # In case this is a re-run move the cofi preload out of the way
    if [ -e $R/etc/ld.so.preload ]; then
        mv -v $R/etc/ld.so.preload $R/etc/ld.so.preload.disable
    fi
    mount -t proc none $R/proc
    mount -t sysfs none $R/sys
    mount -o bind /dev $R/dev
    mount -o bind /dev/pts $R/dev/pts
    echo "nameserver 8.8.8.8" > $R/etc/resolv.conf
}

# Unmount host system
function umount_system() {
    umount -l $R/sys
    umount -l $R/proc
    umount -l $R/dev/pts
    umount -l $R/dev
    echo "" > $R/etc/resolv.conf
}

function sync_to() {
    local TARGET="${1}"
    if [ ! -d "${TARGET}" ]; then
        mkdir -p "${TARGET}"
    fi
    # rsync -a --progress --delete ${R}/ ${TARGET}/
    rsync -a --delete ${R}/ ${TARGET}/
}

function generate_locale() {
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

    for LOCALE in $(chroot $R locale | cut -d'=' -f2 | grep -v : | sed 's/"//g' | uniq); do
        if [ -n "${LOCALE}" ]; then
            chroot $R locale-gen $LOCALE
            chroot $R update-locale LC_ALL=$LOCALE
        fi
    done
    chroot $R dpkg-reconfigure --frontend=noninteractive locales
}

# Set up initial sources.list
function apt_sources() {
    cat <<EOM >$R/etc/apt/sources.list
deb http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE} main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE}-updates main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE}-security main restricted universe multiverse

deb http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
deb-src http://ports.ubuntu.com/ ${RELEASE}-backports main restricted universe multiverse
EOM

    cat <<EOM >$R/etc/apt/apt.conf.d/50raspi
# Never use pdiffs, current implementation is very slow on low-powered devices
Acquire::PDiffs "0";
EOM

}

function apt_update_only() {
    chroot $R apt-get update
}

function apt_clean() {
    chroot $R apt-get -y autoremove
    chroot $R apt-get clean
}

function create_groups() {
    chroot $R groupadd -f --system input

    cat <<'EOM' >$R/usr/local/sbin/adduser.local
#!/bin/sh
# This script is executed as the final step when calling `adduser`
# USAGE:
#   adduser.local USER UID GID HOME

usermod -a -G adm,input $1
EOM
    chmod +x $R/usr/local/sbin/adduser.local
}

# Create default user
function create_user_pocket() {
    local DATE=$(date +%m%H%M%S)
    local PASSWD=$(mkpasswd -m sha-512 pocket ${DATE})

    # Set up default user
    chroot $R adduser --gecos "Pocket Cluster User" --add_extra_groups --disabled-password pocket
    chroot $R usermod -a -G sudo,adm -p ${PASSWD} pocket
    echo "pocket ALL=(ALL) NOPASSWD:ALL" | tee "${R}/etc/sudoers.d/pocket"
}

function configure_ssh() {
    chroot $R apt-get -y install openssh-server
    cat <<EOM >$R/etc/systemd/system/sshdgenkeys.service
[Unit]
Description=SSH key generation on first startup
Before=ssh.service
ConditionPathExists=|!/etc/ssh/ssh_host_key
ConditionPathExists=|!/etc/ssh/ssh_host_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key.pub

[Service]
ExecStart=/usr/bin/ssh-keygen -A
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=ssh.service
EOM

    mkdir -p $R/etc/systemd/system/ssh.service.wants
    chroot $R ln -s /etc/systemd/system/sshdgenkeys.service /etc/systemd/system/ssh.service.wants

    # this is a new way to enable ssh-keygen service. But, the two lines above never failed. so let's mute. 2016-05-19
    #chroot $R systemctl enable ssh-keygen
}

function configure_network() {
    # Set up hosts
    echo ${FLAVOUR} >$R/etc/hostname
    cat <<EOM >$R/etc/hosts
127.0.0.1       localhost
# ::1             localhost ip6-localhost ip6-loopback
# ff02::1         ip6-allnodes
# ff02::2         ip6-allrouters

127.0.1.1       ${FLAVOUR}
EOM

    # Set up interfaces
    if [ "${FLAVOUR}" != "ubuntu-minimal" ] && [ "${FLAVOUR}" != "ubuntu-standard" ]; then
        cat <<EOM >$R/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

# The loopback network interface
auto lo
iface lo inet loopback
EOM
    else
        cat <<EOM >$R/etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

# The loopback network interface
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOM
    fi
}

function setup_developer_package() {
    chroot $R apt-get -y install sudo whois
}

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

function unarchive_base_image() {
    # Need to figure out how to sync links
    #local BASE_IMAGE="xenial-preinstalled-core-arm64.tar.gz"
    local BASE_IMAGE="ubuntu-standard-16.04.1-arm64-base.tar.gz"
    local TARGET="${1}"
    if [ ! -d "${TARGET}" ]; then
        mkdir -p "${TARGET}"
    fi
    #tar -xvzf "${PWD}/../${BASE_IMAGE}" -C ${TARGET} .
    (tar -xvzf "${PWD}/../${BASE_IMAGE}" -C ${TARGET})
}

#------------------------------------------------PINE64--------------------------------------------
function add_platform_scripts() {
    # Install platform scripts
    mkdir -p ${R}/usr/local/sbin
    cp -av ${PWD}/PLATFORM-SCRIPTS/* $R/usr/local/sbin
    chroot $R chown root.root /usr/local/sbin/*
    chmod 755 ${R}/usr/local/sbin/*
}

function add_mackeeper_service() {
    cat > "$R/etc/systemd/system/eth0-mackeeper.service" <<EOF
[Unit]
Description=Fix eth0 mac address to uEnv.txt
After=systemd-modules-load.service local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pine64_eth0-mackeeper.sh

[Install]
WantedBy=multi-user.target
EOF
    chroot $R systemctl enable eth0-mackeeper
}

function add_corekeeper_service() {
    cat > "$R/etc/systemd/system/cpu-corekeeper.service" <<EOF
[Unit]
Description=CPU corekeeper
[Service]
ExecStart=/usr/local/sbin/pine64_corekeeper.sh
[Install]
WantedBy=multi-user.target
EOF
    chroot $R systemctl enable cpu-corekeeper
}

function setup_kernel() {
    local TEMPKERN=$(mktemp -d -p ${R}/tmp)
    local KERNNAME=${PWD}/KERNEL/linux-pine64-3.10.65-7-pine64-longsleep-28.tar.xz

    echo "Extracting Kernel..."
    mkdir ${TEMPKERN}/update
    tar -C ${TEMPKERN}/update --numeric-owner -xJf ${KERNNAME}
    cp -RLp ${TEMPKERN}/update/boot/* $R/boot/
    cp -RLp ${TEMPKERN}/update/lib/* $R/lib/ 2>/dev/null || true
    cp -RLp ${TEMPKERN}/update/usr/* $R/usr/

    echo "Fixing up ..."
    if [ ! -e "${R}/boot/uEnv.txt" -a -e "${R}/boot/uEnv.txt.in" ]; then
        # Install default uEnv.txt when not there.
        mv "${R}/boot/uEnv.txt.in" "${R}/boot/uEnv.txt"
    fi

    rm -rf ${TEMPKERN}

    # Create fstab
    cat <<EOF > "${R}/etc/fstab"
# <file system> <dir>   <type>  <options>           <dump>  <pass>
/dev/mmcblk0p1  /boot   vfat    defaults            0       2
/dev/mmcblk0p2  /   ext4    defaults,noatime        0       1
EOF
}
#--------------------------------------------------------------------------------------------------

function single_stage_build() {
    R="${BASE_R}"
    unarchive_base_image ${R}
    sync_to "${DEVICE_R}"
    R="${DEVICE_R}"
    mount_system

    setup_developer_package
    create_groups
    create_user_pocket
    configure_ssh
    configure_network

    #PINE64 specific scripts
    add_platform_scripts
    add_mackeeper_service
    add_corekeeper_service
    setup_kernel

    apt_clean
    clean_up

    umount_system
}

single_stage_build