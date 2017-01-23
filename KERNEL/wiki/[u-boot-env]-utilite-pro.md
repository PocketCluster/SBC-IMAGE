```
autoload=no
baudrate=115200
bootcmd=run setupmmcboot;mmc dev ${storagedev};if mmc rescan; then run trybootsmz;fi;run setupusbboot;if usb start; then if run loadscript; then run bootscript;fi;fi;run setupsataboot;if sata init; then run trybootsmz;fi;run ;
bootdelay=3
bootm_low=18000000
bootscript=echo Running bootscript from ${storagetype} ...;source ${loadaddr};
console=ttymxc3,115200
doboot=bootm ${loadaddr}
doloadfdt=false
dtb=cm-fx6.dtb
ethprime=FEC0
fdtaddr=0x11000000
kernel=uImage-cm-fx6
loadaddr=0x10800000
loadfdt=load ${storagetype} ${storagedev} ${fdtaddr} ${dtb};
loadkernel=load ${storagetype} ${storagedev} ${loadaddr} ${kernel};
loadscript=load ${storagetype} ${storagedev} ${loadaddr} ${script};
mmcargs=setenv bootargs console=${console} root=${mmcroot} ${video}
mmcroot=/dev/mmcblk0p2 rw rootwait
nandargs=setenv bootargs console=${console} root=${nandroot} rootfstype=${nandrootfstype} ${video}
nandboot=if run nandloadkernel; then run nandloadfdt;run setboottypem;run storagebootcmd;run setboottypez;run storagebootcmd;fi;
nandloadfdt=nand read ${fdtaddr} 780000 80000;
nandloadkernel=nand read ${loadaddr} 0 780000;
nandroot=/dev/mtdblock4 rw
nandrootfstype=ubifs
panel=HDMI
preboot=usb start
run_eboot=echo Starting EBOOT ...; mmc dev 2 && mmc rescan && mmc read 10042000 a 400 && go 10042000
sataargs=setenv bootargs console=${console} root=${sataroot} ${video}
sataroot=/dev/sda2 rw rootwait
script=boot.scr
setboottypem=setenv kernel uImage-cm-fx6;setenv doboot bootm ${loadaddr};setenv doloadfdt false;
setboottypez=setenv kernel zImage-cm-fx6;setenv doboot bootz ${loadaddr} - ${fdtaddr};setenv doloadfdt true;
setupmmcboot=setenv storagetype mmc; setenv storagedev 2;
setupnandboot=setenv storagetype nand;
setupsataboot=setenv storagetype sata; setenv storagedev 0;
setupusbboot=setenv storagetype usb; setenv storagedev 0;
stderr=serial,vga
stdin=serial,usbkbd
stdout=serial,vga
storagebootcmd=echo Booting from ${storagetype} ...;run ${storagetype}args; run doboot;
trybootk=if run loadkernel; then if ${doloadfdt}; then run loadfdt;fi;run storagebootcmd;fi;
trybootsmz=if run loadscript; then run bootscript;fi;run setboottypem;run trybootk;run setboottypez;run trybootk;
video_dvi=mxcfb0:dev=dvi,1280x800M-32@50,if=RGB32
video_hdmi=mxcfb0:dev=hdmi,1920x1080M-32@50,if=RGB32
```