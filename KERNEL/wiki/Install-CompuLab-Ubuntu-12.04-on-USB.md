```bash
wget http://compulab.co.il/utilite-computer/download/utilite/installer/cl-installer_utilite-2_kernel-6.3_2014-12-17.img.xz
unxz cl-installer_utilite-2_kernel-6.3_2014-12-17.img.xz
sudo apt install kpartx
sudo kpartx -g -a -v cl-installer_utilite-2_kernel-6.3_2014-12-17.img
sudo mount /dev/mapper/loop1p2 /mnt
sudo mount /dev/mapper/loop1p1 /mnt/boot/
/bin/echo -e "o\nn\np\n1\n2048\n\nw\n" | sudo fdisk /dev/sdb
sudo mkfs.ext4 -O ^has_journal -b 4096 -L precise /dev/sdb1
sudo mount /dev/sdb1 /media/usb/
cd /mnt
sudo find . | sudo cpio -dump /media/usb/
sudo umount /mnt/boot/
cd ..
sudo umount /mnt/
cd /media/usb/boot
sudo mkdir -p conf.d/default
cd conf.d/default/
sudo ln -s ../.. kernel
echo 'bootscr=
fdt=
ramdisk=
kernel=uImage-cm-fx6
k_rootfs=root=/dev/sdb1 rootwait rw
k_console=console=tty0 console=ttymxc3,115200
k_governor=governor=conservative
k_video=mxcfb0:dev=hdmi,1920x1080M-24@50,if=RGB24
m_set_bootargs=setenv bootargs "${k_console} ${k_rootfs} ${k_governor} ${k_video} net.ifnames=0 apparmor=1 security=apparmor";
run_pre_boot=0' | sudo dd of=uEnv.txt 

