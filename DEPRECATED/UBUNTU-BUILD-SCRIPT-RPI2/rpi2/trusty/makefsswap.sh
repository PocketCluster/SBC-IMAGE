#!/bin/sh

#resize2fs /dev/mmcblk0p2

update-rc.d dphys-swapfile start 20 2 3 4 5 . stop 10 0 1 6 .

service dphys-swapfile start

# Goodbye!
rm /makefsswap.sh
