#!/usr/bin/env bash
: '
This script helps in launching the HDP/HDF clusters through cloudbreak
Pre-requisites:
Cloudbreak UI need to be up and running fine
Cloudbreak must have Azure Credentials added (Azure App Key) with the contributor role
Cloudbreak must have necessary databases for HDP/HDF components
Components required:
1. Cloudbreak Instance details
2. Cloudbreak WebUI along with their credentials
3. Ambari Blueprint for HDP and HDF clusters
4. Azure ARM template file for provisioning the servers
5. Image catalog for the Instances being provisioned by cloudbreak
'

start_script()
{
    if [ -d "/var/log/hwx/" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/create_cluster.log
        echo `date "+%Y-%m-%d %H:%M:%S : Log Dir already exists /var/log/hwx"` >> /var/log/hwx/create_cluster.log
    else
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/create_cluster.log
        $(mkdir /var/log/hwx) && echo `date "+%Y-%m-%d %H:%M:%S : Created log dir /var/log/hwx"` >> /var/log/hwx/create_cluster.log
    fi
}

add_log() { echo `date "+%Y-%m-%d %H:%M:%S : $1"` >> /var/log/hwx/create_cluster.log; }

exit_script()
{
    add_log "Error !!! $1 !!!"
    add_log "Exiting the script execution"
    exit 1
}



