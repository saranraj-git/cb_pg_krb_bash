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
    if [[ $sestatus == "disabled" ]]; then 
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


make_cb()
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
add_log "Creating Cloudbreak directory /var/lib/cloudbreak-deployment"
if [[ $(mkdir -p /var/lib/cloudbreak-deployment) -eq 0 ]];then add_log "Cloudbreak dir created succesfully"; else exit_script "Unable to create Cloudbreak directory"; fi
export IP=$(ip add | grep 'state UP' -A2 | head -n3 | awk '{print $2}' | cut -f1 -d'/' | tail -n1)
add_log "Machine IP detected as $IP"
add_log "Creating Profile file for Cloudbreak"
if [[ -e /var/lib/cloudbreak-deployment/Profile ]]; then
rm -f /var/lib/cloudbreak-deployment/Profile
cat >> /var/lib/cloudbreak-deployment/Profile << END
export UAA_DEFAULT_SECRET=Hadoop-123
export UAA_DEFAULT_USER_PW=Hadoop-123
export UAA_DEFAULT_USER_EMAIL=cbadmin@example.com
export PUBLIC_IP=$IP
END
else
cat >> /var/lib/cloudbreak-deployment/Profile << END
export UAA_DEFAULT_SECRET=Hadoop-123
export UAA_DEFAULT_USER_PW=Hadoop-123
export UAA_DEFAULT_USER_EMAIL=cbadmin@example.com
export PUBLIC_IP=$IP
END
fi
if [[ $(wc -l /var/lib/cloudbreak-deployment/Profile | cut -f1 -d" ") -eq 4 ]]; then add_log "Profile file generated successfully"; else exit "Unable to generate Profile file in /var/lib/cloudbreak-deployment"; fi
add_log "Clearing yml files in /var/lib/cloudbreak-deployment"
if [[ $(rm /var/lib/cloudbreak-deployment/*.yml) -eq 0 ]]; then add_log "Cleanup successfully"; else add_log "No existing yml file(s) found so ignoring ..."; fi
cd /var/lib/cloudbreak-deployment && cbd generate && add_log "Cloudbreak profile generated in /var/lib/cloudbreak-deployment"
add_log "Downloading Docker images"
cd /var/lib/cloudbreak-deployment && cbd pull-parallel && add_log "Docker images download completed"
rm -f /tmp/*.tar 2> /dev/null
rm -f /tmp/*.tar.gz 2> /dev/null
rm -f /var/www/html/cb/*.* 2> /dev/null
if [[ $(cd /tmp/ && docker save traefik:v1.6.6-alpine > traefikv1.6.6-alpine.tar) -eq 0 ]]; then add_log "Docker image 1 : traefik saved"; else exit_script "error downloading Traefik";fi
if [[ $(cd /tmp/ && docker save hortonworks/haveged:1.1.0 >  hortonworks_haveged:1.1.0.tar) -eq 0 ]]; then add_log "Docker image 2 : hortonworks_haveged saved"; else exit_script "error downloading hortonworks_haveged";fi
if [[ $(cd /tmp/ && docker save gliderlabs/consul-server:0.5 > gliderlabs_consul-server:0.5.tar) -eq 0 ]]; then add_log "Docker image 3 : gliderlabs_consul saved"; else exit_script "error downloading gliderlabs_consul";fi
if [[ $(cd /tmp/ && docker save gliderlabs/registrator:v7 > gliderlabs_registrator:v7.tar) -eq 0 ]]; then add_log "Docker image 4 : gliderlabs/registrato saved"; else exit_script "error downloading gliderlabs/registrato";fi
if [[ $(cd /tmp/ && docker save hortonworks/socat:1.0.0 > hortonworks_socat:1.0.0.tar) -eq 0 ]]; then add_log "Docker image 5 : socat saved"; else exit_script "error downloading socat";fi
if [[ $(cd /tmp/ && docker save hortonworks/logspout:v3.2.2 > hortonworks_logspout:v3.2.2.tar) -eq 0 ]]; then add_log "Docker image 6 : logspout saved"; else exit_script "error downloading logspout";fi
if [[ $(cd /tmp/ && docker save hortonworks/logrotate:1.0.1 > hortonworks_logrotate:1.0.1.tar) -eq 0 ]]; then add_log "Docker image 7 : logrotate saved"; else exit_script "error downloading logrotate";fi
if [[ $(cd /tmp/ && docker save catatnight/postfix:latest > catatnight_postfix:latest.tar) -eq 0 ]]; then add_log "Docker image 8 : postfix saved"; else exit_script "error downloading postfix";fi
if [[ $(cd /tmp/ && docker save hortonworks/cbd-smartsense:0.13.4 > hortonworks_cbd-smartsense:0.13.4.tar) -eq 0 ]]; then add_log "Docker image 9 : smartsense saved"; else exit_script "error downloading smartsense";fi
if [[ $(cd /tmp/ && docker save postgres:9.6.1-alpine > postgres:9.6.1-alpine.tar) -eq 0 ]]; then add_log "Docker image 10 : postgres saved"; else exit_script "error downloading postgres";fi
if [[ $(cd /tmp/ && docker save hortonworks/cloudbreak-uaa:3.6.5-pgupdate > hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar) -eq 0 ]]; then add_log "Docker image 11 : cloudbreak-uaa:3.6.5 saved"; else exit_script "error downloading cloudbreak-uaa:3.6.5";fi
if [[ $(cd /tmp/ && docker save hortonworks/cloudbreak:2.9.0 > hortonworks_cloudbreak:2.9.0.tar) -eq 0 ]]; then add_log "Docker image 12 : cloudbreak:2.9.0 saved"; else exit_script "error downloading cloudbreak:2.9.0";fi
if [[ $(cd /tmp/ && docker save hortonworks/hdc-auth:2.9.0 > hortonworks_hdc-auth:2.9.0.tar) -eq 0 ]]; then add_log "Docker image 13 : hdc-auth saved"; else exit_script "error downloading hdc-auth";fi
if [[ $(cd /tmp/ && docker save hortonworks/hdc-web:2.9.0 > hortonworks_hdc-web:2.9.0.tar) -eq 0 ]]; then add_log "Docker image 14 : hdc-web saved"; else exit_script "error downloading hdc-web";fi
if [[ $(cd /tmp/ && docker save hortonworks/cloudbreak-autoscale:2.9.0 > hortonworks_cloudbreak-autoscale:2.9.0.tar) -eq 0 ]]; then add_log "Docker image 15 : cloudbreak-autoscale:2.9.0 saved"; else exit_script "error downloading cloudbreak-autoscale:2.9.0";fi

cd /tmp/
add_log "Archiving the Docker Images...."
if [[ $(tar -czf alldock.tar.gz traefikv1.6.6-alpine.tar hortonworks_haveged:1.1.0.tar gliderlabs_consul-server:0.5.tar gliderlabs_registrator:v7.tar hortonworks_socat:1.0.0.tar hortonworks_logspout:v3.2.2.tar hortonworks_logrotate:1.0.1.tar catatnight_postfix:latest.tar hortonworks_cbd-smartsense:0.13.4.tar postgres:9.6.1-alpine.tar hortonworks_cloudbreak-uaa:3.6.5-pgupdate.tar hortonworks_cloudbreak:2.9.0.tar hortonworks_hdc-auth:2.9.0.tar hortonworks_hdc-web:2.9.0.tar hortonworks_cloudbreak-autoscale:2.9.0.tar ) -eq 0 ]]; then add_log "Archiving docker images successfull"; else exit_script "failed to archive"; fi
}

make_dep()
{
    add_log "Archiving Dependency files...."
    pushd /var/lib/cloudbreak-deployment
    if [[ $(tar -czf cbbin.tar.gz .) -eq 0 ]]; then add_log "Archiving dependencies successfull" ; else exit_script "Archiving dependencies FAILED"; fi
    cp cbbin.tar.gz /tmp/
    cp /bin/cbd /tmp/
    pushd /tmp/
    add_log "Archiving dependencies with docker tar file ...."
    if [[ $(tar -czf mastercb.tar.gz cbbin.tar.gz alldock.tar.gz cbd cb) -eq 0 ]];then add_log "Archiving dependencies with docker files successfull"; else exit_script "Failed to Archive dependencies with docker files"; fi
    if [[ $(mkdir -p /var/www/html/cb) -eq 0 ]];then add_log "Created Dir : /var/www/html/cb "; else exit_script "Unable to create /var/www/html/cb"; fi
    add_log "Copying mastercb.tar.gz to httpd ...."
    if [[ $(cp /tmp/mastercb.tar.gz /var/www/html/cb/ -f) -eq 0 ]]; then add_log "Copied to httpd successfully"; else exit_script "Failed to copy Master Tar file to httpd"; fi
    add_log "Validating the file size of Master Tar file"
    if [[ $(du -h /var/www/html/cb/mastercb.tar.gz | cut -f1) == "2.0G" ]]; then add_log "File Size of mastercb.tar.gz is 2.0GB so proceeding"; else exit_script "TAR ball file contains lesser files than expected";fi
    echo $(cksum /var/www/html/cb/mastercb.tar.gz | cut -f1 -d" ") > /var/www/html/cb/checksum.md5
    add_log "restarting httpd..."
    if [[ $(systemctl enable httpd && systemctl restart httpd) -eq 0 ]]; then add_log "Restarted HTTPD successfully"; else exit_script "ERROR Restarting HTTPD"; fi
    add_log "Cloudbreak Tar file avail at http://$(hostname -f)/cb/mastercb.tar.gz"
    add_log "Script Execution completed Successfully"
}

install_prereq
make_cb
make_dep

