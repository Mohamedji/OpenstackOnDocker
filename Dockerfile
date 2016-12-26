FROM ubuntu:xenial
MAINTAINER mohamedji@outlook.com

ENV OS_USERNAME=admin
ENV OS_PASSWORD=admin_pass
ENV OS_PROJECT_NAME=admin
ENV OS_USER_DOMAIN_NAME=Default
ENV OS_PROJECT_DOMAIN_NAME=Default
ENV OS_AUTH_URL=http://localhost:35357/v3
ENV OS_IDENTITY_API_VERSION=3

# Update ubuntu OS
RUN apt-get update

# Install some dependencies & ifconfig
RUN apt-get install wget vim net-tools software-properties-common python-software-properties -y

# Add openstack newton repository
RUN add-apt-repository cloud-archive:newton -y

# Again Update your OS
RUN apt-get update

# Dependenices for MySQL
ENV DEBIAN_FRONTEND="noninteractive"
RUN debconf-set-selections << 'mysql-server-5.1 mysql-server/root_password password'
RUN debconf-set-selections << 'mysql-server-5.1 mysql-server/root_password_again password'


# Install openvswitch,MySQL,RabbitMQ,Memcached,Keystone,Glance,Neuton,Nove,Cinder & Horizon
RUN apt-get install openvswitch-switch python-mysqldb mysql-server rabbitmq-server memcached python-memcache keystone python-openstackclient \
    glance neutron-server neutron-dhcp-agent neutron-plugin-openvswitch-agent neutron-l3-agent dnsmasq python-neutronclient \
    nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient nova-compute nova-console sysfsutils \
    cinder-api cinder-scheduler cinder-volume qemu lvm2 python-cinderclient openstack-dashboard -y


# Pre-requsite Configuration 
ADD config/interfaces /etc/network/interfaces
ADD config/mysql/mysqld.cnf  /etc/mysql/mysql.conf.d/mysqld.cnf
ADD config/memcached/memcached.conf /etc/memcached.conf
ADD config/sysctl/sysctl.conf /etc/sysctl.conf


# Keystone configuration 
ADD config/keystone/keystone.conf /etc/keystone/keystone.conf
RUN chown keystone:keystone /etc/keystone/keystone.conf


# Glance Configuration 
ADD config/glance/glance-api.conf /etc/glance/glance-api.conf
RUN chown glance:glance /etc/glance/glance-api.conf
ADD config/glance/glance-registry.conf /etc/glance/glance-registry.conf
RUN chown glance:glance /etc/glance/glance-registry.conf
RUN wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

# Neutron Configuration
ADD config/neutron/l3_agent.ini /etc/neutron/l3_agent.ini
RUN chown neutron:neutron /etc/neutron/l3_agent.ini
ADD config/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini
RUN chown neutron:neutron /etc/neutron/dhcp_agent.ini
ADD config/neutron/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
RUN chown neutron:neutron /etc/neutron/plugins/ml2/ml2_conf.ini
ADD config/neutron/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini
RUN chown neutron:neutron  /etc/neutron/plugins/ml2/openvswitch_agent.ini
ADD config/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini
RUN chown neutron:neutron /etc/neutron/plugins/ml2/openvswitch_agent.ini
ADD config/neutron/neutron.conf /etc/neutron/neutron.conf
RUN chown neutron:neutron /etc/neutron/neutron.conf
ADD config/machine-id /etc/machine-id


# Libvirt Config
ADD config/libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf
ADD config/libvirt/libvirt-bin.conf /etc/init/libvirt-bin.conf

# Nova Configuration
ADD config/nova/nova.conf /etc/nova/nova.conf
RUN chown nova:nova /etc/nova/nova.conf
ADD config/nova/nova-compute.conf /etc/nova/nova-compute.conf
RUN chown nova:nova /etc/nova/nova-compute.conf


# Cinder Configuration
ADD config/cinder/cinder.conf /etc/cinder/cinder.conf
RUN chown cinder:cinder /etc/cinder/cinder.conf

# Horizon Configuration
ADD config/horizon/local_settings.py /etc/openstack-dashboard/local_settings.py


EXPOSE 3306 35357 9292 5000 5672 8774 8776 6080 9696 16514 16509 80 

ENTRYPOINT service apache2 restart && service mysql restart && service openvswitch-switch restart && ovs-vsctl add-br br-ex && \ 
           ovs-vsctl add-port br-ex ens33 && service networking restart && \
           service memcached restart && service rabbitmq-server restart && sysctl -p && \
           rabbitmqctl add_user openstack rabbit && rabbitmqctl set_permissions openstack ".*" ".*" ".*" && \
	   mysql -u root -e  "CREATE DATABASE keystone" && mysql -u root -e  "GRANT ALL ON keystone.* TO 'keystoneUser'@'%' IDENTIFIED BY 'keystonePass'" && \
           mysql -u root -e  "GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY 'root1234'" && \ 
           keystone-manage db_sync && keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone && \
	   keystone-manage credential_setup --keystone-user keystone --keystone-group keystone && keystone-manage bootstrap --bootstrap-password admin_pass \
           --bootstrap-admin-url http://localhost:35357/v3/ \
           --bootstrap-internal-url http://localhost:35357/v3/ \
           --bootstrap-public-url http://localhost:5000/v3/ \
           --bootstrap-region-id RegionOne && \

           mysql -u root -e  "CREATE DATABASE glance" && mysql -u root -e  "GRANT ALL ON glance.* TO 'glanceUser'@'%' IDENTIFIED BY 'glancePass'" && \
           openstack project create --domain default --description "Service Project" service && \
           openstack project create --domain default --description "Demo Project" demo \
           && openstack user create --domain default --password demo_pass demo && openstack role create user && \
           openstack role add --project demo --user demo user && \            
           openstack user create --domain default --password service_pass glance && openstack role add --project service --user glance admin && \
           openstack service create --name glance --description "OpenStack Image service" image && \
           openstack endpoint create --region RegionOne image public http://localhost:9292 && \
           openstack endpoint create --region RegionOne image internal http://localhost:9292 && \
           openstack endpoint create --region RegionOne image admin http://localhost:9292 && \
           service glance-registry restart && service glance-api restart &&  glance-manage db_sync && \
           openstack image create "cirros"  --file cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --public && \
           mysql -u root -e  "CREATE DATABASE neutron" && mysql -u root -e  "GRANT ALL ON neutron.* TO 'neutronUser'@'%' IDENTIFIED BY 'neutronPass'" && \ 
           openstack user create --domain default --password service_pass neutron && \
           openstack role add --project service --user neutron admin && \
           openstack service create --name neutron --description "OpenStack Networking" network && \
           openstack endpoint create --region RegionOne network public http://localhost:9696 && \
           openstack endpoint create --region RegionOne network internal http://localhost:9696 && \
           openstack endpoint create --region RegionOne network admin http://localhost:9696 && \
           neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head && \
           service neutron-server restart && service neutron-openvswitch-agent restart && service neutron-metadata-agent restart && \
           service neutron-dhcp-agent restart && service neutron-l3-agent restart && service neutron-l3-agent restart && \
           service dnsmasq restart && \
           mysql -u root -e  "CREATE DATABASE nova" && mysql -u root -e  "GRANT ALL ON nova.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass'" && \
           mysql -u root -e  "CREATE DATABASE nova_api" && mysql -u root -e  "GRANT ALL ON nova_api.* TO 'novaUser'@'%' IDENTIFIED BY 'novaPass'" && \
           openstack user create --domain default --password service_pass nova && \
           openstack role add --project service --user nova admin && \
           openstack service create --name nova --description "OpenStack Compute" compute && \
           openstack endpoint create --region RegionOne compute public http://localhost:8774/v2.1/%\(tenant_id\)s && \
           openstack endpoint create --region RegionOne compute internal http://localhost:8774/v2.1/%\(tenant_id\)s && \
           openstack endpoint create --region RegionOne compute admin http://localhost:8774/v2.1/%\(tenant_id\)s && \
           nova-manage api_db sync && nova-manage db sync && \
           service nova-api restart && service nova-cert restart && service nova-conductor restart && \
           service nova-consoleauth restart && service nova-novncproxy restart && service nova-scheduler restart && \
           service nova-console restart && service libvirt-bin restart && service virtlogd restart && service nova-compute restart && \
           mysql -u root -e  "CREATE DATABASE cinder" && mysql -u root -e  "GRANT ALL ON cinder.* TO 'cinderUser'@'%' IDENTIFIED BY 'cinderPass'" && \
           openstack user create --domain default --password service_pass cinder && \
           openstack role add --project service --user cinder admin && \
           openstack service create --name cinder --description "OpenStack Block Storage" volume && \
           openstack endpoint create --region RegionOne volume public http://localhost:8776/v1/%\(tenant_id\)s && \
           openstack endpoint create --region RegionOne volume internal http://localhost:8776/v1/%\(tenant_id\)s &&\
           openstack endpoint create --region RegionOne volume admin http://localhost:8776/v1/%\(tenant_id\)s && \
           openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2 && \
           openstack endpoint create --region RegionOne volumev2 public http://localhost:8776/v2/%\(tenant_id\)s && \
           openstack endpoint create --region RegionOne volumev2 internal http://localhost:8776/v2/%\(tenant_id\)s &&\
           openstack endpoint create --region RegionOne volumev2 admin http://localhost:8776/v2/%\(tenant_id\)s && \
           cinder-manage db sync && pvcreate -ff /dev/sdb -y && vgcreate -ff cinder-volumes /dev/sdb -y && \
           service tgt restart && service cinder-volume restart && service cinder-scheduler restart &&\
           service cinder-api restart  && \
           openstack network create --external public && openstack subnet create --network public --subnet-range \
           172.17.0.0/16 --dns-nameserver 8.8.8.8  --allocation-pool start=172.17.0.100,end=172.17.0.200  subnet1 && \
           openstack flavor create --id 1 --ram 512 --disk 1 --ephemeral 0 --swap 0 --vcpus 1 --public m1.tiny && \
           /bin/bash
