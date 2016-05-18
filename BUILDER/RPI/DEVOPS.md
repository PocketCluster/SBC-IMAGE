# DevOps

### (05/17/2016)
**Using ip addr instead of ifconfig reports “RTNETLINK answers: File exists” on Debian [link](http://unix.stackexchange.com/questions/100588/using-ip-addr-instead-of-ifconfig-reports-rtnetlink-answers-file-exists-on-de)**  

```
# check network status
$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         192.168.2.1     0.0.0.0         UG        0 0          0 eth0
192.168.0.0     0.0.0.0         255.255.255.0   U         0 0          0 eth1
```  
```
# bring an interface up & down
$ ifconfig eth1 down
$ ifup -v eth1
```  
```  
# flush interface
$ ip addr flush dev eth1
```
- - -  
**Monitor network traffic volume over interface [link](http://serverfault.com/questions/336854/monitor-network-traffic-volume-over-interface)**  
```
$ watch ifconfig eth0
```  
or  
```
$ watch -n 1 -d ifconfig eth0
```
- - -  
**Module control**

```sh
$ modprobe
$ modinfo
$ lsmod
```
> References

[Linux Kernel Modules - Load, Unload, Configure](http://edoceo.com/howto/kernel-modules)
- - -  
**How to prevent a linux kernel `module` to be loaded**
Add a target module to `/etc/modprobe.d/blacklist.conf`.  

```sh
blacklist module_name
```
Check `/usr/modprobe.d/` as well.

> References

[Kernel modules](https://wiki.archlinux.org/index.php/kernel_modules)
- - -  
**How to prevent systemd-modules-load.service load redundant modules**  

```sh
$ rm /lib/modules-load.d/rpi2.conf (or anything don't matter)

```  
- - -  
**How to prevent UDEV from change `eth0` to a random interface (A.K.A. Predicatable Network Interface names)**

1. check if `udev` really changed your interface.  

  ```sh
dmesg | grep udev | grep rename
```  

2. Add following line in `/boot/firmware/cmdline.txt`.  

  ```sh
net.ifnames=0 biosdevname=0
```  

3. Create null file in `/etc/udev/rules.d/` <- _this might not work_.  

  ```sh
touch /etc/udev/rules.d/80-net-setup-link.rules
```

4. Remove the address attribute for specific interface only. (In case multiple ethernet devices, this might fail). We can further work out when firstly boot, check MAC address and substitute MAC address section.  

  ```sh
# USB device 0x:0x (smsc95xx)
# SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="b8:27:eb:b9:ad:9d", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"  
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"  
```

> References

[Predictable Network Interface Names](https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/)  
[Something is renaming my eth0 and wlan0 interfaces](http://ubuntu-mate.community/t/something-is-renaming-my-eth0-and-wlan0-interfaces/2884/1)

### (05/16/2016)
**Check `systemctl` error message in detail**  

1. Find the systemd services which fail to start.  

  ```sh
$ systemctl --failed  
------------------------------------------------------------------------
systemd-modules-load.service   loaded failed failed  Load Kernel Modules
```

2. We want to know more.  

  ```sh
$ systemctl status systemd-modules-load  
------------------------------------------------------------------------
systemd-modules-load.service - Load Kernel Modules      
   Loaded: loaded (/usr/lib/systemd/system/systemd-modules-load.service; static)     
   Active: failed (Result: exit-code) since So 2013-08-25 11:48:13 CEST; 32s ago  
     Docs: man:systemd-modules-load.service(8).  
           man:modules-load.d(5)
  Process: 15630 ExecStart=/usr/lib/systemd/systemd-modules-load (code=exited, status=1/FAILURE)
```  

  If the Process ID is not listed, just restart the failed service with.  

  ```sh  
$ systemctl restart systemd-modules-load
```

3. Now we have the process id (PID) to investigate this error in depth.  

  ```sh
$ journalctl _PID=15630
----------------------------------------------------------------------
-- Logs begin at Sa 2013-05-25 10:31:12 CEST, end at So 2013-08-25 11:51:17 CEST. --
Aug 25 11:48:13 mypc systemd-modules-load[15630]: Failed to find module 'blacklist usblp'
Aug 25 11:48:13 mypc systemd-modules-load[15630]: Failed to find module 'install usblp /bin/false'
```

4. After investigation, try to start systemd-modules-load.  

  ```sh  
$ systemctl restart systemd-modules-load  
$ systemctl status systemd-modules-load
----------------------------------------------------------------------
systemd-modules-load.service - Load Kernel Modules
   Loaded: loaded (/usr/lib/systemd/system/systemd-modules-load.service; static)
   Active: active (exited) since So 2013-08-25 12:22:31 CEST; 34s ago
     Docs: man:systemd-modules-load.service(8)
           man:modules-load.d(5)
 Process: 19005 ExecStart=/usr/lib/systemd/systemd-modules-load (code=exited, status=0/SUCCESS)
Aug 25 12:22:31 mypc systemd[1]: Started Load Kernel Modules.  
```

> References  

[How do I figure out why systemctl service “systemd-modules-load” fails?](http://superuser.com/questions/997938/how-do-i-figure-out-why-systemctl-service-systemd-modules-load-fails)  
[Investigating_systemd_errors](https://wiki.archlinux.org/index.php/systemd#Investigating_systemd_errors)  
[Systemd](https://wiki.gentoo.org/wiki/Systemd)
- - - 
**How to recover RPI3 boot disk**

```sh
# copy only the boot firmware sector. 
# /dev/mmcblk0 : [DEVEL 2016-05-05] XENIAL
# /dev/sda     : Old Ubuntu Image
$ dd if=/dev/mmcblk0 of=/dev/sda bs=512 count=131072
```