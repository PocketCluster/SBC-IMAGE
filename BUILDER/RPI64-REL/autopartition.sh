#!/usr/bin/env bash

# Create the partition, format it and then mount it
echo "partitioning managed disk image"
# expand partition + setup swap partition
/opt/pocket/bin/pocketd fdisk
# Let kernel re-read partition table
partprobe
# wait for the partition to actually exist, timeout after about 5 seconds
sync
sleep 1
# resize 2nd partition
resize2fs /dev/mmcblk0p2
sync
# make swap space
mkswap /dev/mmcblk0p3
sync
# turn swap space
swapon /dev/mmcblk0p3
sync
# add swap to fstable
cat <<EOM >/etc/fstab
proc              /proc    proc    defaults            0    0
/dev/mmcblk0p2    /        ext4    defaults,noatime    0    1
/dev/mmcblk0p1    /boot    vfat    defaults            0    2
/dev/mmcblk0p3    none     swap    sw                  0    0
EOM
sync
