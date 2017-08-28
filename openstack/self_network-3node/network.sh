
#更换为国内镜像源
sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt-get update  

#动态生成密码可用于后文
#root@controller-VirtualBox:~openssl rand -hex 10


#controller and compute node add controller compute
sed -i '$a 10.30.10.145 controller' /etc/hosts
sed -i '$a 10.30.10.141 compute' /etc/hosts
sed -i '$a 10.30.10.160 network' /etc/hosts


############################
#controller chrony
apt install chrony -y
sed 's/NTP server./server controller iburst/g' -i /etc/chrony/chrony.conf
sed 's#\#allow 0/0 (allow access by any IPv4 node)#allow 10.30.10.0/24#g' -i /etc/chrony/chrony.conf
service chrony restart

chronyc sources


#compute chrony
apt install chrony -y
sed 's#pool 2.debian.pool.ntp.org offline iburst#\#pool 2.debian.pool.ntp.org offline iburst#g' -i /etc/chrony/chrony.conf
sed 's/# NTP server./server controller iburst/g' -i /etc/chrony/chrony.conf
sed 's#\#pool 2.debian.pool.ntp.org offline iburst#pool 2.debian.pool.ntp.org offline iburst#g' -i /etc/chrony/chrony.conf
service chrony restart
chronyc sources
############################



#Enable the OpenStack repository
apt install software-properties-common -y
add-apt-repository cloud-archive:newton

apt update -y&& apt dist-upgrade -y




##self-service networks start
#-------------------------------------------------------
apt install  neutron-plugin-ml2 \
  neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent \
  neutron-metadata-agent -y

vim /etc/neutron/neutron.conf
[database]
...去除connection
#connection = mysql+pymysql://neutron:a6fef16aa0395fa62270@controller/neutron
#网络节点去除上面配置

sed 's#connection = sqlite:////var/lib/neutron/neutron.sqlite#\#connection = mysql+pymysql://neutron:a6fef16aa0395fa62270@controller/neutron#g' -i /etc/neutron/neutron.conf

[DEFAULT]

verbose = True
rpc_backend = rabbit
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

sed 's#\#service_plugins =#service_plugins = router#g' -i /etc/neutron/neutron.conf
sed 's#\#allow_overlapping_ips = false#allow_overlapping_ips = True#g'  -i /etc/neutron/neutron.conf


[DEFAULT]
...
auth_strategy = keystone

sed 's#\#auth_strategy = keystone#auth_strategy = keystone#g'  -i /etc/neutron/neutron.conf


[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = a6fef16aa0395fa62270



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


sed 's#\[matchmaker_redis\]#\nauth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = neutron\npassword = a6fef16aa0395fa62270\n\[matchmaker_redis\]#g' -i /etc/neutron/neutron.conf





vim /etc/neutron/plugins/ml2/ml2_conf.ini
[ml2]
...
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
...
flat_networks = external

[ml2_type_vxlan]
...
vni_ranges = 1:1000

[securitygroup]
...
enable_ipset = True


vim /etc/neutron/plugins/ml2/linuxbridge_agent.ini

[linux_bridge]
physical_interface_mappings = external:enp0s3

[vxlan]
enable_vxlan = True
local_ip = 10.30.10.160
l2_population = True

[securitygroup]
...
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

[agent]
tunnel_types = vxlan
prevent_arp_spoofing = True



vim /etc/neutron/l3_agent.ini
[DEFAULT]
...
verbose = True
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
external_network_bridge =


vim  /etc/neutron/dhcp_agent.ini
[DEFAULT]
...
verbose = True
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = True







##controller metadata_agent
vim /etc/neutron/metadata_agent.ini

[DEFAULT]
...
nova_metadata_ip = controller
metadata_proxy_shared_secret = a6fef16aa0395fa62270


sed 's#\#nova_metadata_ip = 127.0.0.1#nova_metadata_ip = controller#g'  -i /etc/neutron/metadata_agent.ini
sed 's#\#metadata_proxy_shared_secret =#metadata_proxy_shared_secret = a6fef16aa0395fa62270#g' -i /etc/neutron/metadata_agent.ini


先回到Controller節點，編輯/etc/nova/nova.conf，在[neutron]部分加入以下設定：
[neutron]
...
service_metadata_proxy = True
metadata_proxy_shared_secret = METADATA_SECRET

重启 controller的nova-api
service nova-api restart



service neutron-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
service neutron-l3-agent restart



