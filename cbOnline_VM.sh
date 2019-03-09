#/bin/env bash
echo "###################################"
echo "Installing Pre-requisites"
yum -y install net-tools ntp wget lsof unzip tar iptables-services httpd
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
cd /var/lib/cloudbreak-deployment && for img in `grep "image:" docker-compose.yml | sed 's/image: //g'`; do [ ! -z $(docker images -q $img) ] || echo "$img" ; done

pushd /tmp/
docker save traefik:v1.6.6-alpine > traefikv1.6.6-alpine.tar
docker save hortonworks/haveged:1.1.0 >  hortonworks_haveged:1.1.0.tar
docker save gliderlabs/consul-server:0.5 > gliderlabs_consul-server:0.5.tar
docker save gliderlabs/registrator:v7 > gliderlabs_registrator:v7.tar
docker save hortonworks/socat:1.0.0 > hortonworks_socat:1.0.0.tar
docker save hortonworks/logspout:v3.2.2 > hortonworks_logspout:v3.2.2.tar
docker save hortonworks/logrotate:1.0.1 > hortonworks_logrotate:1.0.1.tar
docker save catatnight/postfix:latest > catatnight_postfix:latest.tar
docker save hortonworks/cbd-smartsense:0.13.4 > hortonworks_cbd-smartsense:0.13.4.tar
docker save postgres:9.6.1-alpine > postgres:9.6.1-alpine.tar
docker save hortonworks/cloudbreak-uaa:3.6.5-pgupdate > hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar
docker save hortonworks/cloudbreak:2.9.0 > hortonworks_cloudbreak:2.9.0.tar
docker save hortonworks/hdc-auth:2.9.0 > hortonworks_hdc-auth:2.9.0.tar
docker save hortonworks/hdc-web:2.9.0 > hortonworks_hdc-web:2.9.0.tar
docker save hortonworks/cloudbreak-autoscale:2.9.0 > hortonworks_cloudbreak-autoscale:2.9.0.tar

tar -czf alldock.tar.gz traefikv1.6.6-alpine.tar hortonworks_haveged:1.1.0.tar gliderlabs_consul-server:0.5.tar gliderlabs_registrator:v7.tar hortonworks_socat:1.0.0.tar hortonworks_logspout:v3.2.2.tar hortonworks_logrotate:1.0.1.tar catatnight_postfix:latest.tar hortonworks_cbd-smartsense:0.13.4.tar postgres:9.6.1-alpine.tar hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar hortonworks_cloudbreak:2.9.0.tar hortonworks_hdc-auth:2.9.0.tar hortonworks_hdc-web:2.9.0.tar hortonworks_cloudbreak-autoscale:2.9.0.tar 

pushd /var/lib/cloudbreak-deployment
tar -czf cbbin.tar.gz .
cp cbbin.tar.gz /tmp/
cp /bin/cbd /tmp/
pushd /tmp/
tar -czf mastercb.tar.gz cbbin.tar.gz alldock.tar.gz cbd
ll -h mastercb.tar.gz
mkdir /var/www/html/cb
cp mastercb.tar.gz /var/www/html/cb/
systemctl enable httpd && systemctl restart httpd
echo "=== Download Cloudbreak Binaries here ===="
echo "http://$IP/cb/mastercb.tar.gz"
