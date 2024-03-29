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

# Base debootstrap
function bootstrap() {
    # Required tools
    apt-get -y install binfmt-support debootstrap f2fs-tools qemu-user-static rsync ubuntu-keyring wget whois
    update-binfmts --enable qemu-${DEVICE_ARCH}

    # Use the same base system for all flavours.
    if [ ! -f "${R}/tmp/.bootstrap" ]; then
        if [ "${ARCH}" == "${DEVICE_ARCH}" ]; then
            debootstrap --variant=minbase --verbose $RELEASE $R http://ports.ubuntu.com/
        else
            qemu-debootstrap --variant=minbase --verbose --arch=arm64 $RELEASE $R http://ports.ubuntu.com/
        fi
        touch "$R/tmp/.bootstrap"
    fi
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

function apt_update_upgrade() {
    chroot $R apt-get update
    chroot $R apt-get upgrade
}

function apt_upgrade() {
    chroot $R apt-get update
    chroot $R apt-get -y -u dist-upgrade
}

function apt_clean() {
    chroot $R apt-get -y autoremove
    chroot $R apt-get clean
}

# Install Ubuntu Tiny
function ubunty_tiny() {
    # Basic Packages
    chroot $R apt-get -y install language-pack-en-base f2fs-tools software-properties-common u-boot-tools isc-dhcp-client udev netbase ifupdown iproute iputils-ping wget net-tools wpasupplicant ntpdate ntp less tzdata console-common nano console-data
    # Config timezone, Keyboard, Console
    chroot $R dpkg-reconfigure --frontend=noninteractive tzdata
    # chroot $R dpkg-reconfigure --frontend=noninteractive keyboard-configuration
    # chroot $R dpkg-reconfigure --frontend=noninteractive console-setup
}

# Install Ubuntu minimal
function ubuntu_minimal() {
    chroot $R apt-get -y install f2fs-tools software-properties-common
    if [ ! -f "${R}/tmp/.minimal" ]; then
        chroot $R apt-get -y install ubuntu-minimal
        touch "${R}/tmp/.minimal"
    fi
}

# Install Ubuntu minimal
function ubuntu_standard() {
    if [ "${FLAVOUR}" != "ubuntu-minimal" ] && [ ! -f "${R}/tmp/.standard" ]; then
        chroot $R apt-get -y install ubuntu-standard
        touch "${R}/tmp/.standard"
    fi
}

function create_groups() {
#    chroot $R groupadd -f --system gpio
#    chroot $R groupadd -f --system i2c
    chroot $R groupadd -f --system input
#    chroot $R groupadd -f --system spi

    # Create adduser hook
# 2016-04-03 original line was following
# usermod -a -G adm,gpio,i2c,input,spi,video $1

    cat <<'EOM' >$R/usr/local/sbin/adduser.local
#!/bin/sh
# This script is executed as the final step when calling `adduser`
# USAGE:
#   adduser.local USER UID GID HOME

# Add user to the Raspberry Pi specific groups
usermod -a -G adm,input,video $1
EOM
    chmod +x $R/usr/local/sbin/adduser.local
}

# Create default user
function create_user() {
    local DATE=$(date +%m%H%M%S)
    local PASSWD=$(mkpasswd -m sha-512 ${USERNAME} ${DATE})

    if [ ${OEM_CONFIG} -eq 1 ]; then
        chroot $R addgroup --gid 29999 oem
        chroot $R adduser --gecos "OEM Configuration (temporary user)" --add_extra_groups --disabled-password --gid 29999 --uid 29999 ${USERNAME}
    else
        chroot $R adduser --gecos "${FLAVOUR_NAME}" --add_extra_groups --disabled-password ${USERNAME}
    fi
    chroot $R usermod -a -G sudo -p ${PASSWD} ${USERNAME}
}

# Prepare oem-config for first boot.
function prepare_oem_config() {
    if [ ${OEM_CONFIG} -eq 1 ]; then
        chroot $R /bin/systemctl set-default oem-config.target
    fi
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

function add_scripts() {
    if [ "${FLAVOUR}" == "ubuntu-mate" ]; then
        cat <<'EOF' >$R/usr/local/bin/graphical
#!/usr/bin/env bash
# Call with either enable or disable as first parameter

if [ $(id -u) -ne 0 ]; then
    echo "ERROR! $(basename $) must be run as 'root'."
    exit 1
fi

if [ "$1" == "enable" ]; then
    systemctl set-default graphical.target
elif [ "$1" == "disable" ]; then
    systemctl set-default multi-user.target
else
    echo "$(basename $0) should be invoked with with either 'enable' or 'disable' as first parameter."
fi
EOF
        chmod +x $R/usr/local/bin/graphical
    fi
}

function configure_minimal_hardware() {
    local FS="${1}"
    if [ "${FS}" != "ext4" ] && [ "${FS}" != 'f2fs' ]; then
        echo "ERROR! Unsupport filesystem requested. Exitting."
        exit 1
    fi

    chroot $R apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys AB19BAC9
    echo "deb http://deb.odroid.in/c2/ xenial main" >  $R/etc/apt/sources.list.d/odroid.list
    chroot $R apt-get update
    
    # install ODROID kernel
    chroot $R apt-get install -y u-boot-tools initramfs-tools

    # make the kernel package create a copy of the current kernel here
    touch $R/boot/uImage
    chroot $R apt-get install -y linux-image-c2 bootini
}

function install_docker() {
    # install go
    chroot $R apt-add-repository -y ppa:ubuntu-lxc/lxd-stable
    chroot $R apt-get update
    chroot $R apt-get -y install golang docker.io
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

function make_tarball() {
    if [ ${MAKE_TARBALL} -eq 1 ]; then
        rm -f "${BASEDIR}/${TARBALL}" || true
        tar -cSf "${BASEDIR}/${TARBALL}" $R
    fi
}

function make_archive() {
    tar -czf "${BASEDIR}/${BASE_IMAGE}" -C $R .
}

function single_stage_odroid() {
    R="${BASE_R}"

# --- We'll use ubuntu_tiny instead ---
#    bootstrap
#    mount_system

#    generate_locale
#    apt_sources
#    apt_upgrade
#    ubuntu_minimal
#    ubuntu_standard
#    apt_clean
# -------------------------------------

    bootstrap
    mount_system

    generate_locale
    apt_sources
    apt_update_only
    ubunty_tiny
    apt_clean

    umount_system
    sync_to "${DEVICE_R}"
    R="${DEVICE_R}"
    mount_system

    create_groups
    create_user
    prepare_oem_config
    configure_ssh
    configure_network
    add_scripts

#    apt_upgrade
#    apt_clean

#    umount_system
#    clean_up
#    sync_to ${DEVICE_R}
#    make_tarball
#    R=${DEVICE_R}
#    mount_system

    configure_minimal_hardware ${FS_TYPE}
#    configure_hardware ${FS_TYPE}
#    install_software
#    install_docker
#    apt_upgrade

    apt_clean
    clean_up

    umount_system
#    make_raspi2_image ${FS_TYPE} ${FS_SIZE}
}

single_stage_odroid
