#!/usr/bin/env bash
: '

NOTE : This script needs to be executed in the Cloudbreak Instance !!!

This script helps in the following:
  1. Installing the pre-requisites of Cloudbreak
  2. Download required containers and Install Cloudbreak 
  3. Configure Cloudbreak
  4. Start the Cloudbreak Web UI
  5. Enabling Cloudbreak to start during boot time
'

echo "###################################"
echo "Installing Pre-requisites"
yum -y install net-tools ntp wget lsof unzip tar iptables-services
systemctl enable ntpd && systemctl start ntpd
systemctl disable firewalld && systemctl stop firewalld
iptables --flush INPUT && iptables --flush FORWARD && service iptables save
setenforce 0

echo "###################################"
echo "Disabling SE Linux"
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
getenforce

echo "###################################"
echo "Installing Docker"
yum install -y -q docker
systemctl start docker
systemctl enable docker
yum install yum-utils -y -q
yum-config-manager --enable rhui-REGION-rhel-server-extras
sed -i 's/journald/json-file/g'  /etc/sysconfig/docker

echo "###################################"
echo "Configuring docker"
cat /etc/sysconfig/docker | grep "log-driver"
systemctl restart docker
systemctl status docker

echo "###################################"
echo "Installing Cloudbreak"
yum install epel-release -y
yum install jq -y
curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_2.9.0_$(uname)_x86_64.tgz | sudo tar -xz -C /bin cbd

echo "###################################"
echo "$(cbd --version)"
echo "Creating Profile file for Cloudbreak"
mkdir -p /var/lib/cloudbreak-deployment && cd /var/lib/cloudbreak-deployment
export IP=$(ip add | grep 'state UP' -A2 | head -n3 |awk '{print $2}' | cut -f1 -d'/' | tail -n1)
cat >> Profile << END
export UAA_DEFAULT_SECRET=Hadoop-123
export UAA_DEFAULT_USER_PW=Hadoop-123
export UAA_DEFAULT_USER_EMAIL=cbadmin@example.com
export PUBLIC_IP=$IP
END
rm *.yml

echo "###################################"
echo "Generating yml files for cloudbreak docker images"
cd /var/lib/cloudbreak-deployment && cbd generate

echo "###################################"
echo "Downloading Cloudbreak docker images"
cd /var/lib/cloudbreak-deployment && cbd pull-parallel  
rm -f /var/lib/cloudbreak-deployment/certs/*

echo "###################################"
echo "Starting cloudbreak"
cd /var/lib/cloudbreak-deployment && cbd kill && cbd start 

echo "###################################"
echo "Enabling Cloudbreak to start during boot time"
echo "cd /var/lib/cloudbreak-deployment && cbd kill && cbd start" >> /etc/rc.d/rc.local && chmod +x /etc/rc.d/rc.local

echo "###################################"
echo "Start using Cloudbreak"
echo "Cloudbreak WebUI URL : https://$IP"
echo "Username : cbadmin@example.com"
echo "Password : Hadoop-123"

