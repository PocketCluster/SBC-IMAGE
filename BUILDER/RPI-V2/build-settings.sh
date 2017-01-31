#!/usr/bin/env bash

########################################################################
#
# Copyright (C) 2016 Sung-Taek, Kim <stkim1@pocketcluster.io>
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
DEVICE_ARCH="armhf"

DIST_NAME="pocketcluster"
DIST_HOSTNAME="pocket-node"

# Either 'ext4' or 'f2fs'
FS_TYPE="ext4"
# DISK UUID
FS_ROOT_UUID="f4266041-4dd6-4455-a75b-d410db654cca"

# Either 0 or 1.
# - 0 don't make generic rootfs tarball
# - 1 make a generic rootfs tarball
MAKE_TARBALL=1

BASEDIR=${PWD}/RPI
BASE_R=${BASEDIR}/BASE
DEVICE_R=${BASEDIR}/DEVICE
BUILDDIR=${BASEDIR}/BUILD

ARCH=$(uname -m)
export TZ=UTC