# Synopsis
This tutorial describes useful things if you want to set up and run Docker on your RaspberryPi from scratch.
If you prefer a ready to use image you may want to read [this article](http://blog.hypriot.com/post/brand-new-getting-started-guide/) and take the image provided by the [Hypriot team](http://blog.hypriot.com/). As always some people feel better if they can do the set up by themselves and don't need to trust other people's images. If you belong to this particular group you may want to continue reading.
 
# 0 Before you start
You will need a Raspberry Pi running Raspbian. I've taken the [stand alone image](https://www.raspberrypi.org/downloads/raspbian/) (and not NOOBS), since I wanted to use the Raspberry Pi headless.

# 1 Make a raspbian server from a default raspbian image
The official Raspbian comes with a lot of packages pre-installed, many of them don't make sense if you want to run the Raspberry Pi as a server (e.g. without a display attached). So I've decided to delete packages I'm not going to miss very much (thanks to [cnxsoft](http://www.cnx-software.com/2012/07/31/84-mb-minimal-raspbian-armhf-image-for-raspberry-pi/)).    
```
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep x11 | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep python | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep sound | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep gnome | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep lxde | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep gtk | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep desktop | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep gstreamer | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep avahi | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep dbus | sed s/install//`
$ sudo apt-get -y remove `sudo dpkg --get-selections | grep -v "deinstall" | grep freetype | sed s/install//`
$ sudo apt-get -y autoremove
$ sudo apt-get clean
```
# 2 Update to Debian 8 (Jessie)
Debian 8 for the Raspberry Pi already comes with a Docker enabled kernel, but you have to run the update on your own  (there is no ready to use Debian 8 image available for download at this time.). I've found [this tutorial](http://www.desgehtfei.net/?p=30) very helpful for updating to Debian 8:
```
$ sudo sed -i 's/wheezy/jessie/' /etc/apt/sources.list
$ sudo sed -i 's/wheezy/jessie/' /etc/apt/sources.list.d/raspi.list 
$ sudo apt-get update && sudo apt-get -y upgrade # answer 'y' to upcoming questions 
$ sudo sudo apt-get -y dist-upgrade # answer 'y' to upcoming questions
$ sudo init 6
$ sudo apt-get -y autoremove
$ sudo apt-get -y purge $(dpkg -l | awk '/^rc/ { print $2 }')
$ sudo init 6
```

# 3 Build the Docker installation package (optional)
The [Hypriot team](http://blog.hypriot.com/) has made a great job, automating the process of building a [raspbian wheezy package](https://github.com/hypriot/rpi-docker-builder) for Docker, with Docker on ARM. Any docker enabled ARMv7 device will work as well. If you don't have any, you may take a look at [Scaleway](https://www.scaleway.com/), they offer AWS like services based on ARMv7:
```
$ git clone https://github.com/hypriot/rpi-docker-builder.git
$ cd rpi-docker-builder
$ sudo sh build.sh
$ sudo sh run-builder.sh
```
You will find the docker install package in ./dist/docker-hypriot_1.8.1-1_armhf.deb .

# 4 Install the docker installation package on your Raspberry Pi

The Hypriot team offers the [installation package for download](http://blog.hypriot.com/downloads/) now, you don't need to create the installation package by yourself. 

```
$ curl -sSL http://downloads.hypriot.com/docker-hypriot_1.8.1-1_armhf.deb >/tmp/docker-hypriot_1.8.1-1_armhf.deb
$ sudo dpkg -i /tmp/docker-hypriot_1.8.1-1_armhf.deb
$ rm -f /tmp/docker-hypriot_1.8.1-1_armhf.deb
$ sudo sh -c 'usermod -aG docker $SUDO_USER'
$ sudo systemctl enable docker.service
```
See if it works:
```
$ sudo docker info
Containers: 0
Images: 0
Storage Driver: overlay
 Backing Filesystem: extfs
Execution Driver: native-0.2
Logging Driver: json-file
Kernel Version: 4.1.6+
Operating System: Raspbian GNU/Linux 8 (jessie)
CPUs: 1
Total Memory: 434.6 MiB
Name: raspberrypi
ID: 75UW:4ZHU:JAQV:GYD3:EYZO:X47C:R3VE:36X4:2B2Q:SNNC:5XE5:3QUW
Debug mode (server): true
File Descriptors: 11
Goroutines: 21
System Time: 2015-08-30T12:05:37.926439017Z
EventsListeners: 0
Init SHA1: 96cfebcba660bb855cca9d1d6af72fef27a5e953
Init Path: /usr/lib/docker/dockerinit
Docker Root Dir: /var/lib/docker
WARNING: No memory limit support
WARNING: No swap limit support

$ docker version
pi@raspberrypi ~ $ docker version
Client:
 Version:      1.8.1
 API version:  1.20
 Go version:   go1.4.2
 Git commit:   d12ea79-dirty
 Built:        Thu Aug 13 07:53:24 UTC 2015
 OS/Arch:      linux/arm

Server:
 Version:      1.8.1
 API version:  1.20
 Go version:   go1.4.2
 Git commit:   d12ea79-dirty
 Built:        Thu Aug 13 07:53:24 UTC 2015
 OS/Arch:      linux/arm

$ docker run -i -t resin/rpi-raspbian
Unable to find image 'resin/rpi-raspbian:latest' locally
latest: Pulling from resin/rpi-raspbian
0ff226ee0b3d: Pull complete 
53d5a0644416: Pull complete 
699e67a59feb: Pull complete 
cfbba98e0d58: Already exists 
Digest: sha256:0ae72af3cecc0f940b694d7a7a3ccf7003da9460d0cc0d0d9646a8b0d8be9d84
Status: Downloaded newer image for resin/rpi-raspbian:latest
WARNING: Your kernel does not support memory swappiness capabilities, memory swappiness discarded.
root@7672f24fc1a4:/# cat /etc/os-release
PRETTY_NAME="Raspbian GNU/Linux 8 (jessie)"
NAME="Raspbian GNU/Linux"
VERSION_ID="8"
VERSION="8 (jessie)"
ID=raspbian
ID_LIKE=debian
HOME_URL="http://www.raspbian.org/"
SUPPORT_URL="http://www.raspbian.org/RaspbianForums"
BUG_REPORT_URL="http://www.raspbian.org/RaspbianBugs"
root@7672f24fc1a4:/# exit
```
OK, you're done.