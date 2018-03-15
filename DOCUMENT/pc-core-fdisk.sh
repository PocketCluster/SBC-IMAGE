        if [ "$HEADER" = "$MAGIC" ]; then
            # save the preload userdata.tar file
            dd if=$UNPARTITIONED_HD of=/userdata.tar bs=1 count=25600 2>/dev/null
            # Create the partition, format it and then mount it
            echo "NEW pc-core managed disk image ($UNPARTITIONED_HD): formatting it for use"
            echo "NEW pc-core managed disk image ($UNPARTITIONED_HD): formatting it for use" > /home/docker/log.log

            # Add a swap partition (so Docker doesn't complain about it missing)
            (echo n; echo p; echo 2; echo ; echo +1000M ; echo w) | fdisk $UNPARTITIONED_HD
            # Let kernel re-read partition table
            partprobe
            (echo t; echo 82; echo w) | fdisk $UNPARTITIONED_HD
            # Let kernel re-read partition table
            partprobe
            # wait for the partition to actually exist, timeout after about 5 seconds
            local timer=0
            while [ "$timer" -lt 10 -a ! -b "${UNPARTITIONED_HD}2" ]; do
                timer=$((timer + 1))
                sleep 0.5
            done
            mkswap "${UNPARTITIONED_HD}2"
            # Add the data partition
            (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk $UNPARTITIONED_HD
            # Let kernel re-read partition table
            partprobe
            # wait for the partition to actually exist, timeout after about 5 seconds
            timer=0
            while [ "$timer" -lt 10 -a ! -b "${UNPARTITIONED_HD}1" ]; do
                timer=$((timer + 1))
                sleep 0.5
            done
            BOOT2DOCKER_DATA=`echo "${UNPARTITIONED_HD}1"`
            mkfs.ext4 -i 8192 -L $LABEL $BOOT2DOCKER_DATA
            swapon "${UNPARTITIONED_HD}2"
        fi
