#!/bin/bash
start_script()
{
    if [ -d "/var/log/hwx/" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/krb_install.log
        echo `date "+%Y-%m-%d %H:%M:%S : Log Dir already exists /var/log/hwx"` >> /var/log/hwx/krb_install.log
    else
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/krb_install.log
        $(mkdir /var/log/hwx) && echo `date "+%Y-%m-%d %H:%M:%S : Created log dir /var/log/hwx"` >> /var/log/hwx/krb_install.log
    fi
}
export REALMUPPER="TESTDDEP.COM"
export REALMLOWER="testddep.com"
add_log() { echo `date "+%Y-%m-%d %H:%M:%S : $1"` >> /var/log/hwx/krb_install.log; }

exit_script()
{
    add_log "Error !!! $1 !!!"
    add_log "Exiting the script execution"
    exit 1
}

install_krb()
{
    add_log "Installing pre-requisites"
    if [[ $(yum -y install krb5-server krb5-libs krb5-workstation) ]]; then
        add_log "Kerberos Installation successfull"
        add_log "Installed - $(rpm -qa | grep krb5-server)"
        add_log "Installed - $(rpm -qa | grep krb5-libs)"
        add_log "Installed - $(rpm -qa | grep krb5-workstation)"
    else
        exit_script "Error Installing the Kerberos packages"
    fi
}

configure_krb5()
{
    add_log "Updating KRB5.config file..."
    if [[ -e /etc/krb5.conf ]]; then
        add_log "krb5.conf file is available"
        if [[ $(cp /etc/krb5.conf /etc/$(date "+%Y_%m_%d_%H_%M_%S")_krb5.confbkp) -eq 0 ]]; then
            add_log "Backup krb5.conf successful - stored in /etc/$(date "+%Y_%m_%d_%H_%M_%S")_krb5.confbkp"
            sed -i "s/kerberos.example.com/$(hostname -f)/g" /etc/krb5.conf
            sed -i "s/example.com/$REALMLOWER/g" /etc/krb5.conf
            sed -i "s/EXAMPLE.COM/$REALMUPPER/g" /etc/krb5.conf
            sed -i "s/# //g" /etc/krb5.conf
        else
            exit_script "Unable to take the backup of /etc/krb5.conf"
        fi
    else
        exit_script "krb5.conf file is not available"
    fi

}

configure_kadm()
{
    if [[ -e /var/kerberos/krb5kdc/kadm5.acl ]]; then
        add_log "kadm5.acl is available"    
        add_log "Updating kadm.acl file..."
        if [[ $(cp /var/kerberos/krb5kdc/kadm5.acl /var/kerberos/krb5kdc/$(date "+%Y_%m_%d_%H_%M_%S")_kadm5.aclbkp) -eq 0 ]]; then
            sed -i "s/EXAMPLE.COM/$REALMUPPER/g" /var/kerberos/krb5kdc/kadm5.acl
        else
            exit_script "Unable to take the backup of /var/kerberos/krb5kdc/kadm5.acl"
        fi
    else
        exit_script "/var/kerberos/krb5kdc/kadm5.acl is not available, please reinstall the package"
    fi
}

configure_kdc()
{
    add_log "Creating KDC database..."
    echo "Hadoop-123" > /tmp/kdbutilpwd.txt
    echo "Hadoop-123" >> /tmp/kdbutilpwd.txt
    kdb5_util create -s < /tmp/kdbutilpwd.txt
    if [[ $? -eq 0 ]]; then
        add_log "KDC database created successfully"
        systemctl start krb5kdc && systemctl start kadmin
        systemctl enable krb5kdc && systemctl enable kadmin
    else
        exit_script "KDC database creation failed"
    fi
}

open_port()
{
    if [[ $(systemctl is-active firewalld) -eq 0 ]];then
        firewall-cmd --zone=public --add-service=ftp --permanent
        firewall-cmd --zone=public --add-service=telnet --permanent
        firewall-cmd --zone=public --add-service=ssh --permanent
        firewall-cmd --zone=public --add-port=88/tcp --permanent
        firewall-cmd --zone=public --add-port=88/udp --permanent
        firewall-cmd --zone=public --add-port=749/tcp --permanent
        firewall-cmd --zone=public --add-port=749/udp --permanent
        firewall-cmd --zone=public --add-port=543/tcp --permanent
        firewall-cmd --zone=public --add-port=544/tcp --permanent
        firewall-cmd --zone=public --add-port=754/tcp --permanent
        firewall-cmd --reload
        firewall-cmd --list-all
    else
        add_log "Firewalld is not running"
    fi
}


create_princ()
{
    kadmin.local -q "addprinc admin/admin" < /tmp/kdbutilpwd.txt
    kadmin.local -q "addprinc root/admin" < /tmp/kdbutilpwd.txt
    export IP=$(ip add | grep 'state UP' -A2 | head -n3 | awk '{print $2}' | cut -f1 -d'/' | tail -n1)
    add_log "Machine IP detected as $IP"
    kadmin.local -q "addprinc kadmin/$IP@$REALMUPPER" < /tmp/kdbutilpwd.txt
    if [[ $(systemctl restart kadmin && systemctl restart krb5kdc) -eq 0 ]];then
        add_log "Kerberos configured successfully"
        kadmin.local -q "listprincs"
    else
        exit_script "Failed to configure Kerberos"
    fi
    
    add_log "Script Execution completed"
}

start_script
install_krb
configure_krb5
configure_kadm
configure_kdc
open_port
create_princ
