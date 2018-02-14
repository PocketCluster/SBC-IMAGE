#!/usr/bin/env bash

# Create the partition, format it and then mount it
echo "partitioning managed disk image formatting it for use"

# expand partition + setup swap partition
/opt/pocket/bin/pocketd fdisk
# Let kernel re-read partition table
partprobe
# wait for the partition to actually exist, timeout after about 5 seconds
sleep 3
# resize 2nd partition
resize2fs /dev/mmcblk0p2
# make swap space
mkswap /dev/mmcblk0p3
# turn swap space
swapon /dev/mmcblk0p3
# add swap to fstable
echo "/dev/mmcblk0p3 none swap sw 0 0" >> /etc/fstab
# remove autopartition
rm -rf /etc/rc.d/autopartition.sh