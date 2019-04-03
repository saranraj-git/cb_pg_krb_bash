#!/bin/bash
if [[ ! -d /var/log/hwx/ ]]; then
    if [[ $(mkdir -p /var/log/hwx) ]]; then
        echo `date "+%Y-%m-%d %H:%M:%S : Created log dir /var/log/hwx"` >> /var/log/hwx/cb_install.log
    else
        echo `date "+%Y-%m-%d %H:%M:%S : Error creating log dir /var/log/hwx"` >> /var/log/hwx/cb_install.log
        echo `date "+%Y-%m-%d %H:%M:%S : Exiting the script execution"` >> /var/log/hwx/cb_install.log
        exit 1
    fi
fi 

add_log() { echo `date "+%Y-%m-%d %H:%M:%S : $1"` >> /var/log/hwx/cb_install.log; }

add_log "==== Script execution started ===="

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
        add_log "$(rpm -qa | grep net-tools) - Installed"
        add_log "$(rpm -qa | grep ntp) - Installed"
        add_log "$(rpm -qa | grep wget) - Installed"
        add_log "$(rpm -qa | grep lsof) - Installed"
        add_log "$(rpm -qa | grep unzip) - Installed"
        add_log "$(rpm -qa | grep tar) - Installed"
        add_log "$(rpm -qa | grep iptables-services) - Installed"
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
}
