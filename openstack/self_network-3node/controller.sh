
#更换为国内镜像源
sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt-get update  

#动态生成密码可用于后文
#root@controller-VirtualBox:~# openssl rand -hex 10


#controller and compute node add controller compute
sed -i '$a 10.30.10.145 controller' /etc/hosts
sed -i '$a 10.30.10.141 compute' /etc/hosts
sed -i '$a 10.30.10.160 network' /etc/hosts


############################
#controller chrony
apt install chrony -y
sed 's/# NTP server./server controller iburst/g' -i /etc/chrony/chrony.conf
sed 's#\#allow 0/0 (allow access by any IPv4 node)#allow 10.30.10.0/24#g' -i /etc/chrony/chrony.conf
service chrony restart

chronyc sources


#compute chrony
apt install chrony -y
sed 's#pool 2.debian.pool.ntp.org offline iburst#\#pool 2.debian.pool.ntp.org offline iburst#g' -i /etc/chrony/chrony.conf
sed 's/# NTP server./server controller iburst/g' -i /etc/chrony/chrony.conf
service chrony restart
chronyc sources
############################



#Enable the OpenStack repository
apt install software-properties-common -y
add-apt-repository cloud-archive:newton

apt update -y&& apt dist-upgrade -y
apt install python-openstackclient -y



#controller sql
apt install mariadb-server python-pymysql -y


echo -e '[mysqld]\nbind-address = 10.30.10.145\ndefault-storage-engine = innodb\ninnodb_file_per_table\nmax_connections = 4096\ncollation-server = utf8_general_ci\ncharacter-set-server = utf8' >> /etc/mysql/mariadb.conf.d/99-openstack.cnf

service mysql restart
mysql_secure_installation 
#密码设置为 a6fef16aa0395fa62270



#rabbitmq
apt install rabbitmq-server -y
rabbitmqctl add_user openstack a6fef16aa0395fa62270
rabbitmqctl set_permissions openstack ".*" ".*" ".*"


apt install memcached python-memcache -y
sed 's/-l 127.0.0.1/-l 10.30.10.145/' -i /etc/memcached.conf
service memcached restart




#controller config identity service
mysql -u root -p
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'a6fef16aa0395fa62270';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'a6fef16aa0395fa62270';
exit

apt install keystone -y
#vim /etc/keystone/keystone.conf

sed 's#connection = sqlite:////var/lib/keystone/keystone.db#connection = mysql+pymysql://keystone:a6fef16aa0395fa62270@controller/keystone#g' -i /etc/keystone/keystone.conf


#[token]
#provider = fernet
sed 's#\#provider = uuid#provider = fernet#g' -i /etc/keystone/keystone.conf

su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password  a6fef16aa0395fa62270\
  --bootstrap-admin-url http://controller:35357/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne

echo "ServerName controller" >> /etc/apache2/apache2.conf
service apache2 restart
rm -f /var/lib/keystone/keystone.db

export OS_USERNAME=admin
export OS_PASSWORD=a6fef16aa0395fa62270
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3



openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo

#need input a6fef16aa0395fa62270
openstack user create --domain default --password-prompt demo



openstack role create user
openstack role add --project demo --user demo user


# controller node
unset OS_AUTH_URL OS_PASSWORD


#need input a6fef16aa0395fa62270
openstack --os-auth-url http://controller:35357/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name admin --os-username admin token issue

openstack --os-auth-url http://controller:5000/v3 \
  --os-project-domain-name Default --os-user-domain-name Default \
  --os-project-name demo --os-username demo token issue



#vim admin-openrc

#export OS_PROJECT_DOMAIN_NAME=Default
#export OS_USER_DOMAIN_NAME=Default
#export OS_PROJECT_NAME=admin
#export OS_USERNAME=admin
#export OS_PASSWORD=a6fef16aa0395fa62270
#export OS_AUTH_URL=http://controller:35357/v3
#export OS_IDENTITY_API_VERSION=3
#export OS_IMAGE_API_VERSION=2

#vim demo-openrc
#export OS_PROJECT_DOMAIN_NAME=Default
#export OS_USER_DOMAIN_NAME=Default
#export OS_PROJECT_NAME=demo
#export OS_USERNAME=demo
#export OS_PASSWORD=DEMO_PASS
#export OS_AUTH_URL=http://controller:5000/v3
#export OS_IDENTITY_API_VERSION=3
#export OS_IMAGE_API_VERSION=2

echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=admin\nexport OS_USERNAME=admin\nexport OS_PASSWORD=a6fef16aa0395fa62270\nexport OS_AUTH_URL=http://controller:35357/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ~/admin-openrc
echo -e "export OS_PROJECT_DOMAIN_NAME=Default\nexport OS_USER_DOMAIN_NAME=Default\nexport OS_PROJECT_NAME=demo\nexport OS_USERNAME=demo\nexport OS_PASSWORD=a6fef16aa0395fa62270\nexport OS_AUTH_URL=http://controller:5000/v3\nexport OS_IDENTITY_API_VERSION=3\nexport OS_IMAGE_API_VERSION=2" > ~/demo-openrc

. admin-openrc
openstack token issue





#controller image service

mysql -u root -p
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'a6fef16aa0395fa62270';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'a6fef16aa0395fa62270';
exit

. admin-openrc


#need input a6fef16aa0395fa62270
openstack user create --domain default --password-prompt glance


openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292
apt install glance -y

#vim /etc/glance/glance-api.conf
#[database]
# ...
#connection = mysql+pymysql://glance:a6fef16aa0395fa62270@controller/glance




#[keystone_authtoken]
#...
#auth_uri = http://controller:5000
#auth_url = http://controller:35357
#memcached_servers = controller:11211
#auth_type = password
#project_domain_name = Default
#user_domain_name = Default
#project_name = service
#username = glance
#password = a6fef16aa0395fa62270

#[paste_deploy]
# ...
#flavor = keystone

#[glance_store]
# ...
#stores = file,http
#default_store = file
#filesystem_store_datadir = /var/lib/glance/images/


sed 's#\#connection = <None>#connection = mysql+pymysql://glance:a6fef16aa0395fa62270@controller/glance#g' -i /etc/glance/glance-api.conf
sed 's#\[keystone_authtoken\]$#\[keystone_authtoken\]\nauth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = glance\npassword = a6fef16aa0395fa62270\n#g' -i /etc/glance/glance-api.conf

sed 's#\#flavor = keystone#flavor = keystone#' -i /etc/glance/glance-api.conf

sed 's#\#stores = file,http$#stores = file,http#g' -i /etc/glance/glance-api.conf
sed 's#\#default_store = file#default_store = file#g' -i /etc/glance/glance-api.conf
sed 's#\#filesystem_store_datadir = /var/lib/glance/images#filesystem_store_datadir = /var/lib/glance/images/#g' -i /etc/glance/glance-api.conf




#vim /etc/glance/glance-registry.conf
#[database]
# ...
#connection = mysql+pymysql://glance:a6fef16aa0395fa62270@controller/glance
#[keystone_authtoken]
# ...
#auth_uri = http://controller:5000
#auth_url = http://controller:35357
#memcached_servers = controller:11211
#auth_type = password
#project_domain_name = default
#user_domain_name = default
#project_name = service
#username = glance
#password = a6fef16aa0395fa62270


#[paste_deploy]
# ...
#flavor = keystone


sed 's#\#connection = <None>#connection = mysql+pymysql://glance:a6fef16aa0395fa62270@controller/glance#g' -i /etc/glance/glance-registry.conf

sed 's#\[keystone_authtoken\]$#\[keystone_authtoken\]\nauth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = glance\npassword = a6fef16aa0395fa62270\n#g' -i /etc/glance/glance-registry.conf

sed 's#\#flavor = keystone#flavor = keystone#' -i /etc/glance/glance-registry.conf


su -s /bin/sh -c "glance-manage db_sync" glance
service glance-registry restart
service glance-api restart


#controller image service

. admin-openrc
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

openstack image create "cirros" \
  --file cirros-0.3.4-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public

openstack image list




#configure controller node
mysql -u root -p

CREATE DATABASE nova_api;
CREATE DATABASE nova;

GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'a6fef16aa0395fa62270';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'a6fef16aa0395fa62270';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'a6fef16aa0395fa62270';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'a6fef16aa0395fa62270';
exit
. admin-openrc

#need input a6fef16aa0395fa62270
openstack user create --domain default --password-prompt nova

openstack role add --project service --user nova admin

openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create --region RegionOne \
  compute public http://controller:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  compute internal http://controller:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  compute admin http://controller:8774/v2.1/%\(tenant_id\)s


apt install nova-api nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler -y



#vim /etc/nova/nova.conf

[api_database]
connection = mysql+pymysql://nova:a6fef16aa0395fa62270@controller/nova_api
[database]
connection = mysql+pymysql://nova:a6fef16aa0395fa62270@controller/nova
[DEFAULT]
transport_url = rabbit://openstack:a6fef16aa0395fa62270@controller
auth_strategy = keystone

[DEFAULT]

my_ip = 10.30.10.145

[DEFAULT]
...
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
enabled_apis=osapi_compute,metadata





[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = a6fef16aa0395fa62270

[vnc]
vncserver_listen = $my_ip
vncserver_proxyclient_address = $my_ip

[glance]
api_servers = http://controller:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp


su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart



####需要安装完计算节点


# verify operation
. admin-openrc
openstack compute service list


#controller networking

mysql -u root -p
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY 'a6fef16aa0395fa62270';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY 'a6fef16aa0395fa62270';
exit
. admin-openrc

#need input a6fef16aa0395fa62270
 openstack user create --domain default --password-prompt neutron
 openstack role add --project service --user neutron admin

openstack service create --name neutron \
  --description "OpenStack Networking" network

openstack endpoint create --region RegionOne \
  network public http://controller:9696

openstack endpoint create --region RegionOne \
  network internal http://controller:9696

openstack endpoint create --region RegionOne \
  network admin http://controller:9696





##self-service networks start
#-------------------------------------------------------
apt install neutron-server neutron-plugin-ml2 -y

vim /etc/neutron/neutron.conf
[database]
...
connection = mysql+pymysql://neutron:a6fef16aa0395fa62270@controller/neutron


 [DEFAULT]
 ...
 core_plugin = ml2
 service_plugins = router
 allow_overlapping_ips = True
 rpc_backend = rabbit
 auth_strategy = keystone


 [DEFAULT]
 ...


 [keystone_authtoken]
 ...
 auth_uri = http://controller:5000
 auth_url = http://controller:35357
 memcached_servers = controller:11211
 auth_type = password
 project_domain_name = Default
 user_domain_name = Default
 project_name = service
 username = neutron
 password = a6fef16aa0395fa62270



 [DEFAULT]
 ...
 notify_nova_on_port_status_changes = True
 notify_nova_on_port_data_changes = True

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = a6fef16aa0395fa62270


 [nova]
 ...
 auth_url = http://controller:35357
 auth_type = password
 project_domain_name = Default
 user_domain_name = Default
 region_name = RegionOne
 project_name = service
 username = nova
 password = a6fef16aa0395fa62270




 vim /etc/neutron/plugins/ml2/ml2_conf.ini
 [ml2]
 type_drivers = flat,vlan,vxlan
 tenant_network_types = vxlan
 mechanism_drivers = linuxbridge,l2population
 extension_drivers = port_security

 [ml2_type_flat]
 flat_networks = external

 [ml2_type_vxlan]
 vni_ranges = 1:1000

 [securitygroup]
 enable_ipset = True




#vim /etc/nova/nova.conf

#[neutron]
#...
#url = http://controller:9696
#auth_url = http://controller:35357
#auth_type = password
#project_domain_name = Default
#user_domain_name = Default
#region_name = RegionOne
#project_name = service
#username = neutron
#password = a6fef16aa0395fa62270
#service_metadata_proxy = True
#metadata_proxy_shared_secret = a6fef16aa0395fa62270



echo -e "[neutron]\nurl = http://controller:9696\nauth_url = http://controller:35357\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = a6fef16aa0395fa62270\nservice_metadata_proxy = True\nmetadata_proxy_shared_secret = a6fef16aa0395fa62270\n" >> /etc/nova/nova.conf


su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

service nova-api restart
service neutron-server restart




#####此处配置运算节点网络

. admin-openrc
neutron ext-list
openstack network agent list







. admin-openrc
neutron ext-list
openstack network agent list


## self service network  start
. admin-openrc

#openstack network create  --share --external \
#  --provider-physical-network provider \
#  --provider-network-type flat provider



neutron net-create ext-net --router:external \
--provider:physical_network external \
--provider:network_type flat
## neutron net-create ext-net 




openstack network list


#openstack subnet create --network provider \
#--allocation-pool start=10.30.10.210,end=10.30.10.250 \
#--dns-nameserver 114.114.114.114 --gateway 10.30.10.1 \
#--subnet-range 10.30.10.0/24 provider



neutron subnet-create ext-net 10.30.10.0/24 \
--allocation-pool start=10.30.10.230,end=10.30.10.250 \
--disable-dhcp --gateway 10.30.10.1 \
--name ext-subnet

##
neutron subnet-delete ext-subnet


openstack subnet list



. demo-openrc
#openstack network create selfservice

#openstack network list


#openstack subnet create --network selfservice \
#  --dns-nameserver 114.114.114.114 --gateway 172.16.1.1 \
# --subnet-range 172.16.1.0/24 selfservice


neutron net-create demo-net

##d
neutron net-delete demo-net

neutron subnet-create demo-net 172.16.1.0/24 \
--gateway 172.16.1.1 \
--dns-nameserver 114.114.114.114 \
--name demo-subnet

##d
neutron subnet-delete demo-subnet


neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net

##d

neutron router-interface-delete demo-router demo-subnet
neutron router-gateway-clear demo-router ext-net
neutron router-delete demo-router



openstack subnet list


. demo-openrc
#openstack router create router

#neutron router-interface-add router selfservice
#neutron router-gateway-set router provider




. admin-openrc
## create flavor
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano


## apair
. demo-openrc
ssh-keygen -q -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey

openstack keypair list
## add security rules
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default


##self-service network lunch start
. demo-openrc
openstack flavor list
openstack image list
openstack network list
openstack security group list


openstack server create --flavor m1.nano --image cirros \
  --nic net-id=12f924db-2ea2-4386-b2f4-940a60b9b391 --security-group default \
  --key-name mykey selfservice-instance

openstack server list
openstack console url show selfservice-instance

##self-service network lunch end

## provider lunch  start
. demo-openrc
openstack flavor list
openstack image list
openstack network list
openstack security group list


##其它 
###重新启动所有服务
service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
service nova-api restart
service neutron-server restart





neutron router-interface-delete router selfservice
neutron router-gateway-clear router provider
openstack router delete router
openstack subnet delete selfservice
openstack network delete selfservice


