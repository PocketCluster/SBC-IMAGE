#TODO

1. [ ] FAN network setup.  
2. [x] build boot image with local boot image.  
  - PINE64 : uses `/KERNEL/linux-pine64-3.10.65-7-pine64-longsleep-28.tar.xz`  
    * Look `build-devel-filetree.sh` 
  - Odroid C2 : uses `linux-image-3.14.29-56_20160420_arm64.deb`. 
    * Look `build-devel-filetree.sh`  
  - RPI 2/3 : **FIXME** still uses remote images!
3. [x] use xenial-core/base file to reduce distribute size.  
4. [ ] find out how to store links with rsync.  
5. [x] remove unnecessary langauge files.  
  - This should be done along with locale. Take a look at [Translation](https://wiki.ubuntu.com/ReducingDiskFootprint#Translations)	

  ```sh
  If you use packages from universe, /usr/share/locale/ will have a lot of (probably unneeded) translations. If you only need to support a relatively small subset of languages, the unnecessary ones can be filtered out with above dpkg   filters:
  
  # setup filters
  path-exclude /usr/share/locale/*
  path-include /usr/share/locale/en*
  
  # then remove existing translations
  find ${R}/usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' | xargs rm -r
  ```    
6. [x] install proper SSL CA root certs (ca-certificates).  
7. [ ] remove `Unattended Upgrades Shutdown`.  
8. [ ] make RPI image dependencies local, especially `rpi-update`.  
9. [ ] update Odroid `/etc/fstab` in image construction.  
10. [ ] setup swap space according to memory size. Can be easily done based on the device model.  
11. [ ] setup auto partition/format/swap-setup from the first boot. Use **`sfdisk`**.  
  - Look how Hypriot has done in [`/etc/firstboot.d/10-resize-rootdisk`](./DOCUMENT/10-resize-rootdisk.sh)  
  - Look how dhyve-os has done in [`/etc/init.d/S3automount`](./DOCUMENT/S03automount.sh)
  - Look how Odroid-Mate has done in [`/aafirstboot`](./DOCUMENT/first_boot_odroid_mate.sh)
12. [x] `apt-mark hold u-boot-tools` so u-boot won't destroy bootloader.
13. [x] `apt-get install libpam-systemd dbus` to prevent ssh session hang.
14. [ ] `sync` disks before quit.
15. [x] `apt-get install apparmor` for proper apparmor parser.
16. [x] `sysctl -w kernel/keys/root_maxkeys=1000000`
17. [ ] Base add user policy to not include `docker`
18. [ ] Remove `pocket` user from production release
19. [ ] Check to modify `/etc/hostname` and `/etc/hosts` together
20. [ ] Apply techniques from [ReducingDiskFootprint](https://wiki.ubuntu.com/ReducingDiskFootprint) [PDF](DOCUMENT/ReducingDiskFootprint-UbuntuWiki.pdf).
21. [ ] Install only the bare minimum _dependents_. *This has backfired to increase in size.
22. [ ] Remove RaspberryPI VideoCore
23. [ ] Check and make suder `docker.io.deb` package is static build. Otherwise, we're in trouble.
  - We can now build `docker.io` within docker. We can only create daemon binary!
24. [x] Remove mate repository from `RPI-V2` build to make sure it is not contaminated with non-official repo.
25. [ ] RPI 64 FIQ failure 

  - <https://github.com/oerdnj/lede/blob/master/target/linux/brcm2708/patches-4.9/0008-irqchip-irq-bcm2835-Add-2836-FIQ-support.patch>
  - <https://github.com/raspberrypi/linux/blob/rpi-4.9.y/drivers/irqchip/irq-bcm2835.c#L259-L266>

  ```c
  if (is_2836) {
    intc.local_regmap =
      syscon_regmap_lookup_by_compatible("brcm,bcm2836-arm-local");
    if (IS_ERR(intc.local_regmap)) {
      pr_err("Failed to get local register map. FIQ is disabled for cpus > 1\n");
      intc.local_regmap = NULL;
    }
  }
  ```