#!/bin/env bash
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
yum install -y docker-1.13.1-75.git8633870.el7.centos.x86_64 docker-client-1.13.1-75.git8633870.el7.centos.x86_64 docker-common-1.13.1-75.git8633870.el7.centos.x86_64
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
yum install jq epel-release -y
mkdir -p /var/lib/cloudbreak-deployment

echo "###################################"
echo "Getting the TAR ball"
wget http://172.26.253.50/cb/mastercb.tar.gz -O /tmp/mastercb.tar.gz
tar -xzf /tmp/mastercb.tar.gz -C /tmp/
tar -xzf /tmp/alldock.tar.gz -C /tmp/

echo "###################################"
echo "Loading Docker Images"
docker load < /tmp/traefikv1.6.6-alpine.tar
docker load < /tmp/hortonworks_haveged:1.1.0.tar
docker load < /tmp/gliderlabs_consul-server:0.5.tar
docker load < /tmp/gliderlabs_registrator:v7.tar
docker load < /tmp/hortonworks_socat:1.0.0.tar
docker load < /tmp/hortonworks_logspout:v3.2.2.tar
docker load < /tmp/hortonworks_logrotate:1.0.1.tar
docker load < /tmp/catatnight_postfix:latest.tar
docker load < /tmp/hortonworks_cbd-smartsense:0.13.4.tar
docker load < /tmp/postgres:9.6.1-alpine.tar
docker load < /tmp/hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar
docker load < /tmp/hortonworks_cloudbreak:2.9.0.tar
docker load < /tmp/hortonworks_hdc-auth:2.9.0.tar
docker load < /tmp/hortonworks_hdc-web:2.9.0.tar
docker load < /tmp/hortonworks_cloudbreak-autoscale:2.9.0.tar

echo "###################################"
echo "Extracting Cloudbreak binaries & dependencies"
tar -xzf /tmp/cbbin.tar.gz -C /var/lib/cloudbreak-deployment/
cp /tmp/cbd /bin/ && chmod +x /bin/cbd
rm -f /var/lib/cloudbreak-deployment/Profile
rm -f /var/lib/cloudbreak-deployment/*.yml

echo "###################################"
echo "Generating Config File"
export IP=$(ip add | grep 'state UP' -A2 | head -n3 |awk '{print $2}' | cut -f1 -d'/' | tail -n1)
cat >> /var/lib/cloudbreak-deployment/Profile << END
export UAA_DEFAULT_SECRET=Hadoop-123
export UAA_DEFAULT_USER_PW=Hadoop-123
export UAA_DEFAULT_USER_EMAIL=cbadmin@example.com
export PUBLIC_IP=$IP
END
cd /var/lib/cloudbreak-deployment/ && cbd generate

echo "###################################"
echo "Starting Cloudbreak"
cd /var/lib/cloudbreak-deployment/ && cbd start

