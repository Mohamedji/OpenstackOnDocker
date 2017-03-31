#!/usr/bin/sh
echo "Deploying Openstack Newton please wait..."
echo "Installing dependencies..."
apt-get update
apt-get install lvm2 docker.io software-properties-common python-software-properties -y
add-apt-repository cloud-archive:newton -y
apt-get update
apt-get install openvswitch-switch -y
docker build -t openstack .
docker run -itd -p 80:80 -p 6080:6080 --privileged --device=/dev/sdb:/dev/sdb -v /var/run/lvm/lvmetad.socket:/var/run/lvm/lvmetad.socket -v /lib/modules/:/lib/modules openstack /bin/bash
echo "Have a coffee & come back Openstack will be ready for you...."
sleep 5m
echo "Connect to Openstack on http://`(/sbin/ip -o -4 addr list ens33 | awk '{print $4}' | cut -d/ -f1)`/horizon"
echo "Username:admin"
echo "Password:admin_pass"
