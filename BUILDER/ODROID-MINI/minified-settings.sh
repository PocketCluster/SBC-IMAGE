#!/usr/bin/env bash

########################################################################
#
# Copyright (C) 2015 Martin Wimpress <code@ubuntu-mate.org>
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

FLAVOUR="ubuntu-base"
FLAVOUR_NAME="Ubuntu"
RELEASE="xenial"
VERSION="16.04.1"
QUALITY=""
DEVICE_ARCH="aarch64"

DIST_NAME="pocketcluster"
DIST_HOSTNAME="pocket-node"

# Either 'ext4' or 'f2fs'
FS_TYPE="ext4"
# DISK UUID
FS_ROOT_UUID="e139ce78-9841-40fe-8823-96a304a09859"

# Either 0 or 1.
# - 0 don't make generic rootfs tarball
# - 1 make a generic rootfs tarball
MAKE_TARBALL=1

BASEDIR=${PWD}/C2/${RELEASE}
BUILDDIR=${BASEDIR}/${FLAVOUR}
BASE_R=${BASEDIR}/base
DEVICE_R=${BUILDDIR}/odroid
ARCH=$(uname -m)
export TZ=UTC