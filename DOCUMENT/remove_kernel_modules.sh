#!/bin/bash
# Author: Serge Hallyn <serge.hallyn@canonical.com>
# For use with live-helper
# Call this something like 99cleanupmodules and
# place it in config/chroot_local-hooks/

# Unusable example list - get the list from lsmod # on a running system.
# TODO - it's worth adding a function which deduces the actual module
# file based on the name - these are often not quite the same.
MODULES="
	aufs
	bridge
	kvm
	kvm-intel
"

# Now, remove modules that aren't in this list

cleanout_modules()
{
	dir=$1/kernel
	umask 0022
	mkdir ${dir}.new
	for f in $MODULES; do
		path=`find ${dir} -type f -name $f.ko | tail -1`
		if [ "x${path}" = "x" ]; then
			continue
		fi
		d=`dirname ${path}`
		newd=`echo $d | sed 's/kernel/kernel.new/'`
		mkdir -p ${newd}
		mv ${path} ${newd}/
	done
	rm -rf ${dir}
	mv ${dir}.new ${dir}
}

for f in /lib/modules/*; do
	cleanout_modules $f
done
