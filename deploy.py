#!/usr/bin/python
import socket
import fcntl
import struct
print "Deploying Openstack Newton please wait..."
print "Installing dependencies..."
apt-get update
apt-get install lvm2 git software-properties-common python-software-properties -y
add-apt-repository cloud-archive:newton -y
apt-get install openvswitch-switch -y
docker run -itd -p 80:80 -p 6080:6080 --privileged --device=/dev/sdb:/dev/sdb -v /var/run/lvm/lvmetad.socket:/var/run/lvm/lvmetad.socket -v /lib/modules/:/lib/modules mohamedji/openstack /bin/bash
time.sleep(60)
def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])

ip = get_ip_address('eth0')
print "Connect to Openstack on http://"+ip+"/horizon"
print "Username:admin"
print "Password:admin_pass"
