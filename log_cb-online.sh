#!/bin/bash
if [ -d "/var/log/hwx/" ]; then
    echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/cb_install.log
    echo `date "+%Y-%m-%d %H:%M:%S : Log Dir already exists /var/log/hwx"` >> /var/log/hwx/cb_install.log
else
    echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/cb_install.log
    $(mkdir /var/log/hwx) && echo `date "+%Y-%m-%d %H:%M:%S : Created log dir /var/log/hwx"` >> /var/log/hwx/cb_install.log
fi

add_log() { echo `date "+%Y-%m-%d %H:%M:%S : $1"` >> /var/log/hwx/cb_install.log; }

exit_script()
{
    add_log "Error !!! $1 !!!"
    add_log "Exiting the script execution"
    exit 1
}
install_prereq()
{
    add_log "Installing pre-requisites"
    if [[ $(yum -y install net-tools ntp wget lsof unzip tar iptables-services httpd) ]]; then
        add_log "Pre-requisites Installation successfull"
        add_log "Installed - $(rpm -qa | grep net-tools)"
        add_log "Installed - $(rpm -qa | grep ntp)"
        add_log "Installed - $(rpm -qa | grep wget)"
        add_log "Installed - $(rpm -qa | grep lsof)"
        add_log "Installed - $(rpm -qa | grep unzip)"
        add_log "Installed - $(rpm -qa | grep tar)"
        add_log "Installed - $(rpm -qa | grep iptables-services) - Installed"
    else
        exit_script "Error Installing the dependencies"
    fi

    if [[ $(systemctl is-active ntpd) ]]; then 
        systemctl start ntpd && add_log "Started NTP service"
    else 
        exit_script "Unable to start NTP service"
    fi

    if [[ $(systemctl is-enabled ntpd) ]]; then 
        systemctl enable ntpd && add_log "Enabled NTP service to start on boot"
    else 
        exit_script "Unable to set NTP to start on boot"
    fi

    if [[ $(systemctl is-enabled firewalld) ]]; then 
        systemctl disable firewalld && add_log "Disabled FirewallD service to start on boot"
    else 
        add_log "Firewalld already disabled to start on boot"
    fi

    if [[ $(systemctl is-active firewalld) ]]; then 
        systemctl stop firewalld && add_log "Stopped Firewalld service"
    else 
        add_log "FirewallD already stopped"
    fi
    
    if [[ $(iptables --flush INPUT && iptables --flush FORWARD) -eq 0 ]]; then add_log "IPTables Flush successfull" ; else add_log "IPTables Flush failed" ; fi
    if [[ $(service iptables save) ]]; then add_log "IPTables saved" ; else add_log "IPTables save failed" ; fi
    
    if [[ $(getenforce) ]]; then add_log "SELinux is already disabled " ; else add_log "SELinux enabled" ; exit_script "SELinux Enabled"; fi
    

    sestatus=$(cat /etc/selinux/config | grep "^SELINUX" | head -n1 | cut -f2 -d'=')
    if [[ $sestatus -eq 'disabled' ]]; then 
        add_log "SE Linux already disabled during boot"; 
    else 
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config && add_log "Changed SE Linux to disabled in config file"
        add_log "Validating SE Linux again"
        [[ $(getenforce) ]] && add_log "Now SE Linux set to disabled"
    fi

    if [[ $(yum install -y yum-utils docker-1.13.1-75.git8633870.el7.centos.x86_64 docker-client-1.13.1-75.git8633870.el7.centos.x86_64 docker-common-1.13.1-75.git8633870.el7.centos.x86_64) ]]; then
        add_log "Installing Docker 1.13 and yum utils"
        add_log "Installed - $(rpm -qa | grep docker-1.13*)"
        add_log "Installed - $(rpm -qa | grep yum-utils)"
    else
        exit_script "Docker install or yum utils failed"
    fi
    
    if [[ $(systemctl is-enabled docker) == "enabled" ]]; then 
        add_log "Docker already set to start on boot"
    else 
        systemctl enable docker && add_log "Docker service enabled to start on boot"
    fi

    if [[ $(systemctl is-active docker) == "active" ]]; then 
        add_log "Docker already started"
    else 
        systemctl start docker && add_log "Started docker service"
        yum-config-manager --enable rhui-REGION-rhel-server-extras
    fi

    
    if [[ $(cat /etc/sysconfig/docker | grep "log-driver" | cut -f2 -d" " | cut -f2 -d"=") == "json-file" ]]; then
        add_log "Docker already configured to JSON-file"
    else
        sed -i 's/journald/json-file/g'  /etc/sysconfig/docker && add_log "Changing docker config to JSON-file"
        add_log "Validating docker config again"
        if [[ $(cat /etc/sysconfig/docker | grep "log-driver" | cut -f2 -d" " | cut -f2 -d"=") == "json-file" ]]; then add_log "Docker configured to JSON File"; fi
        systemctl restart docker && add_log "Restarting Docker service"
    fi
}


install_cb()
{
    if [[ "$(yum -y install epel-release)" ]]; then
        add_log "Installed - $(rpm -qa | grep epel-release)"
    elif [[ $(yum -y install epel-release jq) == 1 ]]; then
        add_log "Epel release Already installed"
    else
        add_log "Installation Error or Package not avail for JQ and EPEL Release $?"
    fi

    if [[ $(curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_2.9.0_$(uname)_x86_64.tgz | sudo tar -xz -C /bin cbd) -eq 0 ]]; then
        add_log "CBD file downloaded and stored in /bin/"
    else
        add_log "Error Downloading CBD"
    fi

    if [[ $(curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /tmp/) -eq 0 ]]; then
        add_log "CB client downloaded and stored in /tmp/"
    else
        add_log "Error Downloading CB client"
    fi

mkdir -p /var/lib/cloudbreak-deployment 
export IP=$(ip add | grep 'state UP' -A2 | head -n3 |awk '{print $2}' | cut -f1 -d'/' | tail -n1)
cat >> /var/lib/cloudbreak-deployment/Profile << END
export UAA_DEFAULT_SECRET=Hadoop-123
export UAA_DEFAULT_USER_PW=Hadoop-123
export UAA_DEFAULT_USER_EMAIL=cbadmin@example.com
export PUBLIC_IP=$IP
END
rm /var/lib/cloudbreak-deployment/*.yml
cd /var/lib/cloudbreak-deployment && cbd generate && add_log "Cloudbreak profile generated in /var/lib/cloudbreak-deployment"
add_log "Downloading Docker images"
if [[ $(cd /var/lib/cloudbreak-deployment && cbd pull-parallel) ]]; then 
    add_log "Docker images download completed"
else
    add_log "Error Downloading Docker images"
fi

if [[ $(pushd /tmp && docker save traefik:v1.6.6-alpine > traefikv1.6.6-alpine.tar) ]]; then add_log "traefik docker image saved"; else add_log "error downloading Traefik";fi
if [[ $(pushd /tmp && docker save hortonworks/haveged:1.1.0 >  hortonworks_haveged:1.1.0.tar) ]]; then add_log "hortonworks_haveged docker image saved"; else add_log "error downloading hortonworks_haveged";fi
if [[ $(pushd /tmp && docker save gliderlabs/consul-server:0.5 > gliderlabs_consul-server:0.5.tar) ]]; then add_log "gliderlabs_consul docker image saved"; else add_log "error downloading gliderlabs_consul";fi
if [[ $(pushd /tmp && docker save gliderlabs/registrator:v7 > gliderlabs_registrator:v7.tar) ]]; then add_log "gliderlabs/registrato docker image saved"; else add_log "error downloading gliderlabs/registrato";fi

if [[ $(pushd /tmp && docker save hortonworks/socat:1.0.0 > hortonworks_socat:1.0.0.tar) ]]; then add_log "socat docker image saved"; else add_log "error downloading socat";fi
if [[ $(pushd /tmp && docker save hortonworks/logspout:v3.2.2 > hortonworks_logspout:v3.2.2.tar) ]]; then add_log "logspout docker image saved"; else add_log "error downloading logspout";fi

if [[ $(pushd /tmp && docker save hortonworks/logrotate:1.0.1 > hortonworks_logrotate:1.0.1.tar) ]]; then add_log "logrotate docker image saved"; else add_log "error downloading logrotate";fi
if [[ $(pushd /tmp && docker save catatnight/postfix:latest > catatnight_postfix:latest.tar) ]]; then add_log "postfix docker image saved"; else add_log "error downloading postfix";fi
if [[ $(pushd /tmp && docker save hortonworks/cbd-smartsense:0.13.4 > hortonworks_cbd-smartsense:0.13.4.tar) ]]; then add_log "smartsense docker image saved"; else add_log "error downloading smartsense";fi
if [[ $(pushd /tmp && docker save postgres:9.6.1-alpine > postgres:9.6.1-alpine.tar) ]]; then add_log "postgres docker image saved"; else add_log "error downloading postgres";fi

if [[ $(pushd /tmp && docker save hortonworks/cloudbreak-uaa:3.6.5-pgupdate > hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar) ]]; then add_log "cloudbreak-uaa:3.6.5 docker image saved"; else add_log "error downloading cloudbreak-uaa:3.6.5";fi
if [[ $(pushd /tmp && docker save hortonworks/cloudbreak:2.9.0 > hortonworks_cloudbreak:2.9.0.tar) ]]; then add_log "cloudbreak:2.9.0 docker image saved"; else add_log "error downloading cloudbreak:2.9.0";fi
if [[ $(pushd /tmp && docker save hortonworks/hdc-auth:2.9.0 > hortonworks_hdc-auth:2.9.0.tar) ]]; then add_log "hdc-auth docker image saved"; else add_log "error downloading hdc-auth";fi
if [[ $(pushd /tmp && docker save hortonworks/hdc-web:2.9.0 > hortonworks_hdc-web:2.9.0.tar) ]]; then add_log "hdc-web docker image saved"; else add_log "error downloading hdc-web";fi
if [[ $(pushd /tmp && docker save hortonworks/cloudbreak-autoscale:2.9.0 > hortonworks_cloudbreak-autoscale:2.9.0.tar) ]]; then add_log "cloudbreak-autoscale:2.9.0 docker image saved"; else add_log "error downloading cloudbreak-autoscale:2.9.0";fi

tar -czf alldock.tar.gz traefikv1.6.6-alpine.tar hortonworks_haveged:1.1.0.tar gliderlabs_consul-server:0.5.tar gliderlabs_registrator:v7.tar hortonworks_socat:1.0.0.tar hortonworks_logspout:v3.2.2.tar hortonworks_logrotate:1.0.1.tar catatnight_postfix:latest.tar hortonworks_cbd-smartsense:0.13.4.tar postgres:9.6.1-alpine.tar hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar hortonworks_cloudbreak:2.9.0.tar hortonworks_hdc-auth:2.9.0.tar hortonworks_hdc-web:2.9.0.tar hortonworks_cloudbreak-autoscale:2.9.0.tar 
pushd /tmp/
if [[ $(tar -czf alldock.tar.gz traefikv1.6.6-alpine.tar hortonworks_haveged:1.1.0.tar gliderlabs_consul-server:0.5.tar gliderlabs_registrator:v7.tar hortonworks_socat:1.0.0.tar hortonworks_logspout:v3.2.2.tar hortonworks_logrotate:1.0.1.tar catatnight_postfix:latest.tar hortonworks_cbd-smartsense:0.13.4.tar postgres:9.6.1-alpine.tar hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar hortonworks_cloudbreak:2.9.0.tar hortonworks_hdc-auth:2.9.0.tar hortonworks_hdc-web:2.9.0.tar hortonworks_cloudbreak-autoscale:2.9.0.tar ) -eq 0 ]]; then echo "Tar successfull"; else echo "failed"; fi
pushd /var/lib/cloudbreak-deployment
tar -czf cbbin.tar.gz .
cp cbbin.tar.gz /tmp/
cp /bin/cbd /tmp/
pushd /tmp/
tar -czf mastercb.tar.gz cbbin.tar.gz alldock.tar.gz cbd cb
mkdir -p /var/www/html/cb
cp /tmp/mastercb.tar.gz /var/www/html/cb/
systemctl enable httpd && systemctl restart httpd

}

install_prereq
install_cb