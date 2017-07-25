
#更换为国内镜像源
sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt-get update  

#动态生成密码可用于后文
#root@controller-VirtualBox:~# openssl rand -hex 10


#controller and compute node add controller compute
sed -i '$a 10.30.10.145 controller' /etc/hosts
sed -i '$a 10.30.10.141 compute' /etc/hosts



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
vim /etc/keystone/keystone.conf

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

#[api_database]
#connection = mysql+pymysql://nova:a6fef16aa0395fa62270@controller/nova_api
#[database]
#connection = mysql+pymysql://nova:a6fef16aa0395fa62270@controller/nova
#[DEFAULT]
#transport_url = rabbit://openstack:a6fef16aa0395fa62270@controller
#auth_strategy = keystone

#[DEFAULT]
#...
#my_ip = 10.30.10.145

#[DEFAULT]
#...
#use_neutron = True
#firewall_driver = nova.virt.firewall.NoopFirewallDriver
#[keystone_authtoken]
#auth_uri = http://controller:5000
#auth_url = http://controller:35357
#memcached_servers = controller:11211
#auth_type = password
#project_domain_name = Default
#user_domain_name = Default
#project_name = service
#username = nova
#password = a6fef16aa0395fa62270

#[vnc]
#...
#vncserver_listen = $my_ip
#vncserver_proxyclient_address = $my_ip
#[glance]
#...
#api_servers = http://controller:9292
#[oslo_concurrency]
#...
#lock_path = /var/lib/nova/tmp


sed '/connection=sqlite:\/\/\/\/var\/lib\/nova\/nova.sqlite/d' -i /etc/nova/nova.conf
sed 's#\[api_database\]#\[api_database\]\nconnection = mysql+pymysql://nova:a6fef16aa0395fa62270@controller/nova_api#' -i /etc/nova/nova.conf
sed 's#\[database\]#\[database\]\nconnection = mysql+pymysql://nova:a6fef16aa0395fa62270@controller/nova#' -i /etc/nova/nova.conf

sed 's#\[database\]#transport_url = rabbit://openstack:a6fef16aa0395fa62270@controller\nauth_strategy = keystone\nmy_ip = 10.30.10.145\nuse_neutron = True\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver\n\[database\]#g' -i /etc/nova/nova.conf

echo -e "[keystone_authtoken]\nauth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = a6fef16aa0395fa62270\n" >> /etc/nova/nova.conf



###############配置错误
echo -e "[vnc]\nvncserver_listen = \$my_ip\nvncserver_proxyclient_address = \$my_ip\n" >> /etc/nova/nova.conf
echo -e "[glance]\napi_servers = http://controller:9292\n" >> /etc/nova/nova.conf
sed 's#lock_path=/var/lock/nova#lock_path = /var/lib/nova/tmp#g' -i /etc/nova/nova.conf

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


apt install neutron-server neutron-plugin-ml2 \
  neutron-linuxbridge-agent neutron-dhcp-agent \
  neutron-metadata-agent -y





#vim /etc/neutron/neutron.conf

#[database]
#...
#connection = mysql+pymysql://neutron:a6fef16aa0395fa62270@controller/neutron

#[DEFAULT]
#...
#core_plugin = ml2
#service_plugins =

#[DEFAULT]
#...
#transport_url = rabbit://openstack:a6fef16aa0395fa62270@controller
#[DEFAULT]
#...
#auth_strategy = keystone


#[keystone_authtoken]
#...
#auth_uri = http://controller:5000
#auth_url = http://controller:35357
#memcached_servers = controller:11211
#auth_type = password
#project_domain_name = Default
#user_domain_name = Default
#project_name = service
#username = neutron
#password = a6fef16aa0395fa62270




#[DEFAULT]
#...
#notify_nova_on_port_status_changes = True
#notify_nova_on_port_data_changes = True


#[nova]
#...
#auth_url = http://controller:35357
#auth_type = password
#project_domain_name = Default
#user_domain_name = Default
#region_name = RegionOne
#project_name = service
#username = nova
#password = a6fef16aa0395fa62270



sed 's#connection = sqlite:////var/lib/neutron/neutron.sqlite#connection = mysql+pymysql://neutron:a6fef16aa0395fa62270@controller/neutron#g' -i /etc/neutron/neutron.conf
sed 's#\#service_plugins#service_plugins#g' -i /etc/neutron/neutron.conf
sed ':a;N;$!ba;s#\#transport_url = <None>#transport_url = rabbit://openstack:a6fef16aa0395fa62270@controller#' -i /etc/neutron/neutron.conf
sed 's#\#auth_strategy = keystone#auth_strategy = keystone#g'  -i /etc/neutron/neutron.conf
sed 's#\[matchmaker_redis\]#\nauth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = neutron\npassword = a6fef16aa0395fa62270\n\[matchmaker_redis\]#g' -i /etc/neutron/neutron.conf
sed 's#\#notify_nova_on_port_status_changes = true#notify_nova_on_port_status_changes = True#g' -i /etc/neutron/neutron.conf
sed 's#\#notify_nova_on_port_data_changes = true#notify_nova_on_port_data_changes = true#g' -i /etc/neutron/neutron.conf
sed ':a;N;$!ba;s#\[nova\]#\[nova\]\nauth_url = http://controller:35357\nauth_type = password\nuser_domain_name = Default\nproject_domain_name = Default\nregion_name = RegionOne\nproject_name = service\nusername = nova\npassword = a6fef16aa0395fa62270\n#' -i /etc/neutron/neutron.conf






#vim /etc/neutron/plugins/ml2/ml2_conf.ini
#[ml2]
#...
#type_drivers = flat,vlan
#[ml2]
#...
#tenant_network_types =
#[ml2]
#...
#mechanism_drivers = linuxbridge

#[ml2]
#...
#extension_drivers = port_security

#[ml2_type_flat]
#...
#flat_networks = provider
#[securitygroup]
#...
#enable_ipset = True


sed 's#\#type_drivers = local,flat,vlan,gre,vxlan,geneve#type_drivers = flat,vlan#g' -i /etc/neutron/plugins/ml2/ml2_conf.ini
sed 's#\#tenant_network_types = local#tenant_network_types =#g'  -i /etc/neutron/plugins/ml2/ml2_conf.ini
sed 's#\#mechanism_drivers =#mechanism_drivers = linuxbridge#g' -i /etc/neutron/plugins/ml2/ml2_conf.ini
sed 's#\#extension_drivers =#extension_drivers = port_security#g' -i /etc/neutron/plugins/ml2/ml2_conf.ini
sed 's#\#flat_networks = \*#flat_networks = provider#g' -i /etc/neutron/plugins/ml2/ml2_conf.ini
sed 's#\#enable_ipset = true#enable_ipset = True#g' -i /etc/neutron/plugins/ml2/ml2_conf.ini



#vim /etc/neutron/plugins/ml2/linuxbridge_agent.ini

#[linux_bridge]
#physical_interface_mappings = provider:enp0s8

#[vxlan]
#enable_vxlan = False

#[securitygroup]
#...
#enable_security_group = True
#firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

sed 's#\#physical_interface_mappings =#physical_interface_mappings = provider:enp0s8#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed 's#\#enable_vxlan = true#enable_vxlan = False#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed 's#\#enable_security_group = true#enable_security_group = True#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed 's#\#firewall_driver = <None>#firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini





#vim /etc/neutron/dhcp_agent.ini
#[DEFAULT]
#...
#interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
#dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
#enable_isolated_metadata = True

sed 's#\#interface_driver = <None>#interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver#g' -i /etc/neutron/dhcp_agent.ini
sed 's#\#dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq#dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq#g' -i /etc/neutron/dhcp_agent.ini
sed 's#\#enable_isolated_metadata = false#enable_isolated_metadata = True#g' -i /etc/neutron/dhcp_agent.ini


##controller metadata_agent
#vim /etc/neutron/metadata_agent.ini

#[DEFAULT]
#...
#nova_metadata_ip = controller
#metadata_proxy_shared_secret = a6fef16aa0395fa62270


sed 's#\#nova_metadata_ip = 127.0.0.1#nova_metadata_ip = controller#g'  -i /etc/neutron/metadata_agent.ini
sed 's#\#metadata_proxy_shared_secret =#metadata_proxy_shared_secret = a6fef16aa0395fa62270#g' -i /etc/neutron/metadata_agent.ini



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
service neutron-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart



#####此处配置运算节点网络



neutron ext-list
openstack network agent list


#controller
##controller create instance networking
. admin-openrc
openstack network create  --share --external \
--provider-physical-network provider \
--provider-network-type flat provider


openstack subnet create --network provider \
--allocation-pool start=10.30.10.200,end=10.30.10.250 \
--dns-nameserver 114.114.114.114 --gateway 10.30.10.1 \
--subnet-range 10.30.10.0/24 provider

## create flavor
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano
## apair
. demo-openrc
ssh-keygen -q -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey


## add security rules
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default

## lunch 
. demo-openrc
openstack flavor list
openstack image list
openstack network list
openstack security group list


openstack server create --flavor m1.nano --image cirros  --security-group default   --key-name mykey provider-instance

openstack server list
openstack console url show provider-instance




##重新启动所有服务
service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
service nova-api restart
service neutron-server restart
service neutron-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart




