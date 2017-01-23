#TODO

1. [ ] FAN network setup.  
2. [x] build boot image with local boot image.  
  - PINE64 : uses `/KERNEL/linux-pine64-3.10.65-7-pine64-longsleep-28.tar.xz`  
    * Look `build-devel-filetree.sh` 
  - Odroid C2 : uses `linux-image-3.14.29-56_20160420_arm64.deb`. 
    * Look `build-devel-filetree.sh`  
  - RPI 2/3 : **FIXME** still uses remote images!
3. [ ] use xenial-core/base file to reduce distribute size.  
4. [ ] find out how to store links with rsync.  
5. [ ] remove unnecessary langauge files.  
6. [ ] install proper SSL CA root certs.  
7. [ ] remove `Unattended Upgrades Shutdown`.  
8. [ ] make RPI image dependencies local, especially `rpi-update`.  
9. [ ] update Odroid `/etc/fstab` in image construction.  
10. [ ] setup swap space according to memory size. Can be easily done based on the device model.  
11. [ ] setup auto partition/format/swap-setup from the first boot.  
  - Look how Hypriot has done in [`/etc/firstboot.d/10-resize-rootdisk`](./DOCUMENT/10-resize-rootdisk.sh)  
  - Look how dhyve-os has done in [`/etc/init.d/S3automount`](./DOCUMENT/S03automount.sh)
12. [ ] `apt-mark hold u-boot-tools` so u-boot won't destroy bootloader.
13. [ ] `apt-get install libpam-systemd dbus` to prevent ssh session hang.
14. [ ] `sync` disks before quit.
15. [ ] `apt-get install apparmor` for proper apparmor parser.
16. [ ] `sysctl -w kernel/keys/root_maxkeys=1000000`