# Synopsis
This article describes how-to enable the utilte as a WiFi Access Point.

# Before you start

## Install ubuntu 14.04.1

Get and install the ubuntu 14.04.1 install image mentioned [here](https://github.com/umiddelb/armhf/wiki/Installing-Ubuntu-14.04-on-the-utilite-computer-from-scratch#exhibit-download-a-prebuilt-archive-with-kernels-included). This archive comes with the linux 3.10.17 kernel image (default kernel) and the necessary kernel modules needed to run `hostapd (8)`. Newer mainline kernels (3.15, 3.16, etc. ) still lack the support for the build-in Marvell SDIO WiFi interface (`mwifiex`). If you take another kernel image, please make sure that the kernel is compiled with `CONFIG_BRIDGE=y`.

## Verify that your WiFi device is AP-mode capable

You may verify the device's ability to run in AP-mode with `sudo iw list` and look for the section starting with

    ...
    Supported interface modes:
        ...
        * AP
	...

# Set-up the Access Point

## Install and configure `hostapd`

This package isn't included in the install image, you need to install it separately:

    sudo apt-get install hostapd
    sudo echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >/etc/default/hostapd

The `hostapd` configuration file is quite self explanatory, here you find the differences between the shipped version and my recent configuration:

    root@armh0:/etc/hostapd# rcsdiff -r1.1 hostapd.conf
    ===================================================================
    RCS file: hostapd.conf,v
    retrieving revision 1.1
    diff -r1.1 hostapd.conf
    6c6
    < interface=wlan0
    ---
    > interface=uap0
    19c19
    < #bridge=br0
    ---
    > bridge=br0
    25c25
    < # driver=hostap
    ---
    > driver=nl80211
    629c629
    < #ieee8021x=1
    ---
    > ieee8021x=0
    991c991
    < #wpa=1
    ---
    > wpa=2
    1000c1000
    < #wpa_passphrase=secret passphrase
    ---
    > wpa_passphrase=0123456789
    1021c1021
    < #wpa_key_mgmt=WPA-PSK WPA-EAP
    ---
    > wpa_key_mgmt=WPA-PSK WPA-PSK-SHA256
 
## Set-up bridging

If you want to let the utilite operate as a WiFi Access Point you need to bridge the WiFi device and the ethernet device (the necessary package (`bridge-utils`) is already installed). Here you find the network configuration (`/etc/network/interfaces`) doing this on the utilite:

    auto lo br0
    
    iface lo inet loopback
    
    iface br0 inet static
      pre-up iw phy phy0 interface add uap0 type __ap
      address 10.0.0.251
      netmask 255.255.255.0
      network 10.0.0.0
      broadcast 10.0.0.255
      gateway 10.0.0.253
      dns-nameservers 10.0.0.253
      bridge-ports eth0 mlan0

The `pre-up` command creates the AP management interface (`uap0`) for `mlan0` and circumvents the following error:

    ieee80211 phy0: mlan0: changing to 3 not supported

(for further details see [here](https://github.com/gumstix/Gumstix-YoctoProject-Repo/issues/20)). If you add other WiFi USB devices, the numbering for the phy0, phy1, ... device may change.

## Have fun

    service hostapd restart
  




 
