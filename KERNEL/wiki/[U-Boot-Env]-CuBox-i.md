```
baudrate=115200
board=mx6-cubox-i
bootcmd=run m_boot_sata
bootdelay=4
bootenv=uEnv.txt
console=ttymxc0
cpu=6Q
ethact=FEC
ethaddr=d0:63:b4:00:2f:1b
ethprime=FEC
fdt_addr=0x18000000
fdt_high=0xffffffff
initrd_high=0xffffffff
ip_dyn=yes
kernel=zImage
loadaddr=0x10800000
m_boot=if mmc rescan; then setenv v_mode mmc;setenv v_dev ${mmcdev};if run m_loadenv; then echo Importing environment from ${v_mode};env import -t ${loadaddr} ${filesize};fi;if run m_loadbootscript; then echo Running bootscript from ${v_mode} ...;source ${loadaddr};fi;if run m_loadkernel; then run m_mmcargs;if run m_loadftd; then bootz ${loadaddr} - ${fdt_addr};else bootz ${loadaddr};fi;fi;false;else;false;fi;
m_boot_mmc=setenv v_prefix mmc/; run m_boot;
m_boot_sata3=setenv v_prefix sata/; setenv m_mmcargs ${m_sataargs3}; run m_boot;
m_boot_sata.bak=setenv v_prefix sata.bak/; setenv m_mmcargs ${m_sataargs}; run m_boot;
m_boot_sata.old=setenv v_prefix sata.old/; setenv m_mmcargs ${m_sataargs}; run m_boot;
m_boot_sata=setenv v_prefix sata/; setenv m_mmcargs ${m_sataargs}; run m_boot;
m_boot_test=setenv v_prefix test/; setenv m_mmcargs ${m_sataargs}; run m_boot;
m_boot_usb=if usb start; then setenv v_mode usb;setenv v_dev ${usbdev};if usb dev ${v_dev}; then if run m_loadenv; then echo Importing environment from ${v_mode};env import -t ${loadaddr} ${filesize};fi;if run m_loadbootscript; then echo Running bootscript from ${v_mode} ...;source ${loadaddr};fi;if run m_loadkernel; then run m_usbargs;if run m_loadftd; then bootz ${loadaddr} - ${fdt_addr};else bootz ${loadaddr};fi;fi;fi;false;else;false;fi;
m_loadbootscript=if load ${v_mode} ${v_dev} ${loadaddr} /boot/${v_prefix}${bootscr}; then echo Loading ${v_mode}:${v_dev}:/boot/${v_prefix}${bootscr};true;else if load ${v_mode} ${v_dev} ${loadaddr} ${v_prefix}${bootscr}; then echo Loading ${v_mode}:${v_dev}:${v_prefix}${bootscr};true;else echo No bootscript found;false;fi;false;fi;
m_loadenv=if load ${v_mode} ${v_dev} ${loadaddr} /boot/${v_prefix}${bootenv}; then echo Loading ${v_mode}:${v_dev}:/boot/${v_prefix}${bootenv};true;else if load ${v_mode} ${v_dev} ${loadaddr} ${v_prefix}${bootenv}; then echo Loading ${v_mode}:${v_dev}:${v_prefix}${bootenv};true;else echo No ${bootenv} found;false;fi;false;fi;
m_loadftd=if test ${cpu} = 6SOLO || test ${cpu} = 6DL; then setenv fdt_prefix imx6dl;else setenv fdt_prefix imx6q;fi;if test ${board} = mx6-cubox-i; then setenv fdt_file ${fdt_prefix}-cubox-i.dtb;else setenv fdt_file ${fdt_prefix}-hummingboard.dtb;fi;if load ${v_mode} ${v_dev} ${fdt_addr} /boot/${v_prefix}${fdt_file}; then echo Loading ${v_mode}:${v_dev}:/boot/${v_prefix}${fdt_file};true; else if load ${v_mode} ${v_dev} ${fdt_addr} ${v_prefix}${fdt_file}; then echo Loading ${v_mode}:${v_dev}:${v_prefix}${fdt_file};true;else echo No ${fdt_file} found;false;fi;fi;
m_loadkernel=if load ${v_mode} ${v_dev} ${loadaddr} /boot/${v_prefix}${kernel}; then echo Loading ${v_mode}:${v_dev}:/boot/${v_prefix}${kernel};setenv rootpart 1;true;else if load ${v_mode} ${v_dev} ${loadaddr} ${v_prefix}${kernel}; then echo Loading ${v_mode}:${v_dev}:${v_prefix}${kernel};setenv rootpart 2;true;else echo No kernel found;false;fi;fi;
mmcdev=0
m_mmcargs=setenv bootargs console=${console},${baudrate} root=/dev/mmcblk0p${rootpart} rw rootwait;
m_sataargs3=setenv bootargs console=${console},${baudrate} root=/dev/sda3 rw rootwait;
m_sataargs=setenv bootargs console=${console},${baudrate} root=/dev/sda1 rw rootwait;
m_usbargs=setenv bootargs console=${console},${baudrate} root=/dev/sda${rootpart} rw rootwait;
preboot=usb start
script=boot.scr
splashpos=m,m
stderr=serial,vga
stdin=serial,usbkbd
stdout=serial,vga
usbdev=0
```