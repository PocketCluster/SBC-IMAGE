pico /etc/sudoers.d/ubuntu
ubuntu ALL=(ALL) NOPASSWD:ALL

pico /etc/network/interfaces
# --------------- POCKETCLUSTER START ---------------
auto eth0
iface eth0 inet static
dns-nameservers 8.8.8.8
broadcast 192.168.1.255
netmask 255.255.255.0
address 192.168.1.172
gateway 192.168.1.1
# ---------------  POCKETCLUSTER END  ---------------


pico /etc/hostname

pico /etc/hosts
# --------------- POCKETCLUSTER START ---------------
192.168.1.163 pc-node1 pc-node1
192.168.1.164 pc-node2 pc-node2
192.168.1.165 pc-node3 pc-node3
192.168.1.166 pc-node4 pc-node4
192.168.1.167 pc-node5 pc-node5
192.168.1.168 pc-node6 pc-node6
192.168.1.169 pc-node-7 pc-node-7
192.168.1.170 pc-node-8 pc-node-8
192.168.1.171 pc-node-9 pc-node-9
192.168.1.172 pc-node-10 pc-node-10

192.168.1.100 pc-master pc-master
192.168.1.100 salt salt
# ---------------  POCKETCLUSTER END  ---------------

# auth keys
mkdir .ssh
chmod 700 .ssh
vi .ssh/authorized_keys

ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDxxtLwF2sp8lONgTZ9uDy3UwBGADpJl0HxjclNrPO3wqXvh2qlvSzVqf7WK8BVaVlMadMfGgYXCkjJy7O+Eje2RhdUjDni2BLZMGBaAefQom6H9QNk5hX16xJJU2080KZORl4dB6/aMEQ32kDgEAZWDiG0nbJlUGjvLpzJFDqWK98za70gNKtpr1sGELGM6Fvx4J7EF05zGTFFfX0ZP+w6K0CD3i5AHfHxwHdpkJ9jp1XUwb0cBogsxbtdIoX7RzyeEDLBoNTR8fUg5AFuwLymCJ7ozXMgeviuXSInUR5Jc6YYOBlO0MetJ648f7icYIvi9eUIUL6Ds60+FToLwjn9 stkim1@colorfulglue.com

chmod 600 .ssh/authorized_keys


fdisk /dev/mmcblk0
resize2fs /dev/mmcblk0p2


# salt-minion, go, docker
echo "deb http://ppa.launchpad.net/saltstack/salt/ubuntu vivid main" | tee "/etc/apt/sources.list.d/saltstack.list"
wget -q -O- "http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0x4759FA960E27C0A6" | apt-key add -
apt-get update && apt-get -y install salt-minion dphys-swapfile golang docker.io

# salt-check
pico /usr/lib/python2.7/dist-packages/salt/cloud/deploy/bootstrap-salt.sh

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8


