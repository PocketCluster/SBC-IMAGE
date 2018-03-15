#!/usr/bin/env bash

# Create the partition, format it and then mount it
function repartition() {
    echo "partitioning managed disk image"
    # Hardware Disk Sector Size
    local sector_size=$(cat /sys/block/mmcblk0/queue/hw_sector_size)
    # Total Sector Count
    local total_sector_count=$(cat /sys/block/mmcblk0/size)
    # swap partition size in sector 4GB
    local swap_size_in_sector=$((4096 * 1024 * 1024 / ${sector_size}))
    # 2nd partition end sector = Total Disk Sector Count - 4GB in sector
    local second_part_end=$((${total_sector_count} - ${swap_size_in_sector}))

    # delete and revive 2nd partition then add swap
    (echo d; echo 2; echo ; echo n; echo p; echo 2; echo ; echo ${second_part_end}; echo n; echo p; echo 3; echo ; echo ; echo t; echo 3; echo 82; echo w) | fdisk /dev/mmcblk0
}

repartition
sync; sleep 1
# Let kernel re-read partition table
partprobe
# wait for the partition to actually exist, timeout after about 5 seconds
timer=0
while [ "$timer" -lt 5 ]; do
    timer=$((timer + 1))
    sync; sleep 1
done
# resize 2nd partition
resize2fs /dev/mmcblk0p2
sync; sleep 1

# make swap space
mkswap /dev/mmcblk0p3
# Let kernel re-read partition table
partprobe
# wait for the partition to actually exist, timeout after about 5 seconds
timer=0
while [ "$timer" -lt 5 ]; do
    timer=$((timer + 1))
    sync; sleep 1
done
# turn swap space
swapon /dev/mmcblk0p3
sync; sleep 1

# add swap to fstable
cat <<EOM >/etc/fstab
proc              /proc    proc    defaults            0    0
/dev/mmcblk0p2    /        ext4    defaults,noatime    0    1
/dev/mmcblk0p1    /boot    vfat    defaults            0    2
/dev/mmcblk0p3    none     swap    sw                  0    0
EOM
sync; sleep 1
