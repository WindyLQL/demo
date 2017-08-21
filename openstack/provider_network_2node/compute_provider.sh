
#更换为国内镜像源
sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
apt-get update  

#动态生成密码可用于后文
#root@controller-VirtualBox:~# openssl rand -hex 10


#controller and compute node add controller compute
sed -i '$a 10.30.10.145 controller' /etc/hosts
sed -i '$a 10.30.10.141 compute' /etc/hosts


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



#compute node 
apt install nova-compute -y

#vim /etc/nova/nova.conf
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
#username = nova
#password = a6fef16aa0395fa62270

#[DEFAULT]
#...
#my_ip = 10.30.10.141
#[DEFAULT]
#...
#use_neutron = True
#firewall_driver = nova.virt.firewall.NoopFirewallDriver

#[vnc]
#...
#enabled = True
#vncserver_listen = 0.0.0.0
#vncserver_proxyclient_address = $my_ip
#novncproxy_base_url = http://controller:6080/vnc_auto.html

#[glance]
#...
#api_servers = http://controller:9292


#[oslo_concurrency]
#...
#lock_path = /var/lib/nova/tmp


#egrep -c '(vmx|svm)' /proc/cpuinfo
#vim /etc/nova/nova-compute.conf
#[libvirt]
#...
#virt_type = qemu



sed 's#\[database\]#transport_url = rabbit://openstack:a6fef16aa0395fa62270@controller\nauth_strategy = keystone\nmy_ip = 10.30.10.141\nuse_neutron = True\nfirewall_driver = nova.virt.firewall.NoopFirewallDriver\n\[database\]#g' -i /etc/nova/nova.conf

echo -e "[keystone_authtoken]\nauth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = nova\npassword = a6fef16aa0395fa62270\n" >> /etc/nova/nova.conf

echo -e "[vnc]\nenabled = True\nvncserver_listen = 0.0.0.0\nvncserver_proxyclient_address = \$my_ip\nnovncproxy_base_url = http://controller:6080/vnc_auto.html\n" >> /etc/nova/nova.conf

echo -e "[glance]\napi_servers = http://controller:9292\n" >> /etc/nova/nova.conf

sed 's#lock_path=/var/lock/nova#lock_path = /var/lib/nova/tmp#g' -i /etc/nova/nova.conf

sed 's#virt_type=kvm#virt_type = qemu#g' -i /etc/nova/nova-compute.conf

service nova-compute restart








# 验证计算节点，在controller输入完成verify operation
. admin-openrc
openstack compute service list

#compute node networking
apt install neutron-linuxbridge-agent -y



#vim /etc/neutron/neutron.conf

#[database]
#connection
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


sed 's#connection = sqlite:////var/lib/neutron/neutron.sqlite##' -i /etc/neutron/neutron.conf 
sed ':a;N;$!ba;s#\#transport_url = <None>#transport_url = rabbit://openstack:a6fef16aa0395fa62270@controller#' -i /etc/neutron/neutron.conf
sed 's#\#auth_strategy = keystone#auth_strategy = keystone#g' -i /etc/neutron/neutron.conf 
sed 's#\[keystone_authtoken\]$#\[keystone_authtoken\]\nauth_uri = http://controller:5000\nauth_url = http://controller:35357\nmemcached_servers = controller:11211\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nproject_name = service\nusername = neutron\npassword = a6fef16aa0395fa62270\n#' -i /etc/neutron/neutron.conf






#vim /etc/neutron/plugins/ml2/linuxbridge_agent.ini
#[linux_bridge]
#physical_interface_mappings = provider:enp0s3

#[vxlan]
#enable_vxlan = False

#[securitygroup]
#...
#enable_security_group = True
#firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver


sed 's#\#physical_interface_mappings =#physical_interface_mappings = provider:enp0s3#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed 's#\#enable_vxlan = true#enable_vxlan = False#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed 's#\#enable_security_group = true#enable_security_group = True#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed 's#\#firewall_driver = <None>#firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver#g' -i /etc/neutron/plugins/ml2/linuxbridge_agent.ini






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

echo -e "[neutron]\nurl = http://controller:9696\nauth_url = http://controller:35357\nauth_type = password\nproject_domain_name = Default\nuser_domain_name = Default\nregion_name = RegionOne\nproject_name = service\nusername = neutron\npassword = a6fef16aa0395fa62270\n" >> /etc/nova/nova.conf

service nova-compute restart
service nova-compute restart
service neutron-linuxbridge-agent restart



#在controller 节点进行测试
neutron ext-list
openstack network agent list
