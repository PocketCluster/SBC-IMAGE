#! /bin/sh
### BEGIN INIT INFO
# Provides:          aafirstboot
# Required-Start:    $remote_fs $all
# Required-Stop:
# Default-Start:     2 3 4 5 S
# Default-Stop:
# Short-Description: First boot system setup
### END INIT INFO

PATH=/sbin:/usr/sbin:/bin:/usr/bin

. /lib/init/vars.sh
. /lib/lsb/init-functions

case "$1" in
    start)
		if [ -f /.first_boot ]; then
			# ok, its the very first boot, we need to resize the disk.
			p2_start=`fdisk -l /dev/mmcblk0 | grep mmcblk0p2 | awk '{print $2}'`
			p2_finish=$((`fdisk -l /dev/mmcblk0 | grep Disk | grep sectors | awk '{printf $7}'` - 1024))
			
			fdisk /dev/mmcblk0 <<EOF &>> /home/odroid/resize.log
p
d
2
n
p
2
$p2_start
$p2_finish
p
w
EOF
                        rm -fr /.first_boot
			[ ! -f /etc/ssh/ssh_host_rsa_key ] && dpkg-reconfigure openssh-server
                        sync
			reboot
			
		else
		
			# ok, we already resized!
			
			log_daemon_msg "Resizing /" &&
			resize2fs /dev/mmcblk0p2 &&
			rm -fr /aafirstboot
		fi
	;;
    restart|reload|force-reload)
        echo "Error: argument '$1' not supported" >&2
        exit 3
        ;;
    stop)
        ;;
    *)
        echo "Usage: $0 start|stop" >&2
        exit 3
        ;;
esac
