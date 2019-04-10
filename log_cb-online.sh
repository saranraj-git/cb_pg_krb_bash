#!/bin/bash
start_script()
{
    if [ -d "/var/log/hwx/" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/cb_install.log
        echo `date "+%Y-%m-%d %H:%M:%S : Log Dir already exists /var/log/hwx"` >> /var/log/hwx/cb_install.log
    else
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/cb_install.log
        $(mkdir /var/log/hwx) && echo `date "+%Y-%m-%d %H:%M:%S : Created log dir /var/log/hwx"` >> /var/log/hwx/cb_install.log
    fi
}

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

    if [[ $(yum install -y yum-utils docker*1.13.*75* docker-client-1.13*75* docker-common-1.13*75*) ]]; then
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
        if [[ $(cat /etc/sysconfig/docker | grep "log-driver" | cut -f2 -d" " | cut -f2 -d"=") == "json-file" ]]; then add_log "Docker configured to JSON File"; else exit_script "Unable to validate Docker config file"; fi
        systemctl restart docker && add_log "Restarting Docker service"
    fi
    if [[ $(wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -O /tmp/epel.rpm) -eq 0 ]]; then 
        add_log "EPEL repo downloaded successfully in /tmp/epel.rpm"
        if [[ $(rpm -i /tmp/epel.rpm) -eq 0 ]]; then
            add_log "EPEL repo installed successfully - $(rpm -qa | grep epel)"
            if [[ $(yum -y install epel-release jq) -eq 0 ]]; then
                add_log "Installed - $(rpm -qa | grep epel-release)"
                add_log "Installed - $(rpm -qa | grep jq)"
            else
                exit_script "Error installing EPEL-Release and JQ"
            fi
        else
            exit_script "Error Installing EPEL release"
        fi
    else
        exit_script "Unable to download EPEL repo rpm from FEDORA site"
    fi
}


get_cb()
{
    if [[ $(curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_2.9.0_$(uname)_x86_64.tgz | sudo tar -xz -C /bin cbd) -eq 0 ]]; then
        add_log "CBD file downloaded and stored in /bin/"
    else
        exit_script "Error Downloading CBD"
    fi

    if [[ $(curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /tmp/) -eq 0 ]]; then
        add_log "CB client downloaded and stored in /tmp/"
    else
        exit_script "Error Downloading CB client"
    fi
}

make_profile()
{
    add_log "Creating Cloudbreak directory /var/lib/cloudbreak-deployment"
    if [[ $(mkdir -p /var/lib/cloudbreak-deployment) -eq 0 ]];then add_log "Cloudbreak dir created succesfully"; else exit_script "Unable to create Cloudbreak directory"; fi

    export IP=$(ip add | grep 'state UP' -A2 | head -n3 | awk '{print $2}' | cut -f1 -d'/' | tail -n1)
    add_log "Machine IP detected as $IP"
    add_log "Creating Profile file for Cloudbreak"

    if [[ -e /var/lib/cloudbreak-deployment/Profile ]]; then
        mv /var/lib/cloudbreak-deployment/Profile /var/lib/cloudbreak-deployment/$(date "+%Y_%m_%d_%H_%M_%S")_Profile.bkp
        echo "export UAA_DEFAULT_SECRET=Hadoop-123" > /var/lib/cloudbreak-deployment/Profile
        echo "export UAA_DEFAULT_USER_PW=Hadoop-123" >> /var/lib/cloudbreak-deployment/Profile
        echo "export UAA_DEFAULT_USER_EMAIL=cbadmin@example.com" >> /var/lib/cloudbreak-deployment/Profile
        echo "export PUBLIC_IP=$IP" >> /var/lib/cloudbreak-deployment/Profile
    else
        echo "export UAA_DEFAULT_SECRET=Hadoop-123" > /var/lib/cloudbreak-deployment/Profile
        echo "export UAA_DEFAULT_USER_PW=Hadoop-123" >> /var/lib/cloudbreak-deployment/Profile
        echo "export UAA_DEFAULT_USER_EMAIL=cbadmin@example.com" >> /var/lib/cloudbreak-deployment/Profile
        echo "export PUBLIC_IP=$IP" >> /var/lib/cloudbreak-deployment/Profile
    fi

    if [[ $(wc -l /var/lib/cloudbreak-deployment/Profile | cut -f1 -d" ") -eq 4 ]]; then add_log "Profile file generated successfully"; else exit_script "Unable to generate Profile file in /var/lib/cloudbreak-deployment"; fi
    
    add_log "Clearing yml files in /var/lib/cloudbreak-deployment"
    
    if [[ $(rm /var/lib/cloudbreak-deployment/*.yml) -eq 0 ]]; then add_log "yml Cleanup successfully"; else add_log "No existing yml file(s) found so ignoring ..."; fi
}

download_docker()
{
    add_log "Generating YML files"
    [[ $(cd /var/lib/cloudbreak-deployment && cbd generate) ]] && add_log "YML files generated in /var/lib/cloudbreak-deployment" || exit_script "Error generating yml files"
    
    add_log "Downloading Docker images"
    [[ $(cd /var/lib/cloudbreak-deployment && cbd pull-parallel) ]] && add_log "Docker Images download completed" || exit_script "Error Downloading Docker images"
}

archive_docks()
{
    rm -f /tmp/*.tar 2> /dev/null
    rm -f /tmp/*.tar.gz 2> /dev/null
    rm -f /var/www/html/cb/*.* 2> /dev/null
    add_log "Checking the Total count of Docker Images...."
    if [[ $(docker images | sed '1d' | awk '{print $1 ":" $2 }' | wc -l) -ge 17 ]]; then
        add_log "Found Valid num of docker images - $(docker images | sed '1d' | awk '{print $1 ":" $2 }' | wc -l) so proceeding to archive images..."
        add_log "Archiving the Docker Images...."
        if [[ $(docker save $(docker images | sed '1d' | awk '{print $1 ":" $2 }') -o /tmp/alldock.tar) -eq 0 ]];then 
            add_log "Docker images archived successfully in /tmp/alldock.tar"
        else 
            exit_script "Error in Archiving docker images" 
        fi
    else
        add_log "Lesser docker images Found - $(docker images | sed '1d' | awk '{print $1 ":" $2 }' | wc -l)"
        exit_script "Please execute pull-parallel command again"
    fi
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

    if [[ $(tar -czf mastercb.tar.gz cbbin.tar.gz alldock.tar cbd cb) -eq 0 ]];then add_log "Archiving dependencies with docker files successfull"; else exit_script "Failed to Archive dependencies with docker files"; fi
    
    if [[ $(mkdir -p /var/www/html/cb) -eq 0 ]];then add_log "Created Dir : /var/www/html/cb "; else exit_script "Unable to create /var/www/html/cb"; fi
    add_log "Copying mastercb.tar.gz to httpd ...."


    if [[ $(cp /tmp/mastercb.tar.gz /var/www/html/cb/ -f) -eq 0 ]]; then add_log "Copied to httpd successfully"; else exit_script "Failed to copy Master Tar file to httpd"; fi
    add_log "Validating the file size of Master Tar file"

    FILESIZE=$(stat -c%s "/var/www/html/cb/mastercb.tar.gz")
    [[ $FILESIZE > 1718475200 ]] && add_log "File Size of mastercb.tar.gz is more than 1.7GB so proceeding" || exit_script "TAR ball contains lesser files  than expected"
    echo $(cksum /var/www/html/cb/mastercb.tar.gz | cut -f1 -d" ") > /var/www/html/cb/checksum.md5
    add_log "restarting httpd..."
    if [[ $(systemctl enable httpd && systemctl restart httpd) -eq 0 ]]; then add_log "Restarted HTTPD successfully"; else exit_script "ERROR Restarting HTTPD"; fi
    add_log "Cloudbreak Tar file avail at http://$(hostname -f)/cb/mastercb.tar.gz"
    add_log "Script Execution completed Successfully"
}

start_script
install_prereq
get_cb
make_profile
download_docker
archive_docks
make_dep
