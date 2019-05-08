#!/bin/bash
start_script()
{
    if [ -d "/var/log/hwx/" ]; then
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/register_db.log
        echo `date "+%Y-%m-%d %H:%M:%S : Log Dir already exists /var/log/hwx"` >> /var/log/hwx/register_db.log
    else
        echo `date "+%Y-%m-%d %H:%M:%S : Script Execution started"` >> /var/log/hwx/register_db.log
        $(mkdir /var/log/hwx) && echo `date "+%Y-%m-%d %H:%M:%S : Created log dir /var/log/hwx"` >> /var/log/hwx/register_db.log
    fi
}
add_log() { echo `date "+%Y-%m-%d %H:%M:%S : $1"` >> /var/log/hwx/register_db.log; }

exit_script()
{
    add_log "ERROR - $1 !!!"
    add_log "Exiting the script execution"
    exit 1
}

# Getting the inputs as parameter for Cloudbreak WebUI and postgres server 
pgserver="cbpostgres.postgres.database.azure.com"
pgusername="cbpsqladmin@cbpostgres"
pgpwd="Hadoop-12345"
cburl="https://cbvm.com"
cbuser="cbadmin@example.com "
cbpasswd="Hadoop-123"

# Installing and configuring CB utility 
install_cb()
{
    if [[ $(curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /bin cb && chmod +x /bin/cb) -eq 0 ]];then
        add_log "CB utility downloaded successfully"
        if [[ $(cb configure --server $cburl --username $cbuser --password $cbpasswd) -eq 0 ]];then
            add_log "CB configured succcessfully with Cloudbreak VM"
        else
            exit_script "Unable to configure CB Utility with Cloudbreak"
        fi

    else
        exit_script "Failed to Download CB from the internet"
    fi
}

# Register External Postgres DB created for HDP/HDF clusters with Cloudbreak
register_db()
{
    if [[ $(cb database create postgres --name ambaridb --type AMBARI --url jdbc:postgresql://$pgserver:5432/ambari?ssl=true  --db-username $pgusername --db-password $pgpwd) -eq 0 ]]; then
        if [[ $(cb database list --output table | grep HIVE) -eq 0 ]];then
            add_log "Ambari DB registered successfully with Cloudbreak"
        else
            exit_script "Failed to register Ambari DB with Cloudbreak"
        fi
    else
        exit_script "Failed to register Ambari DB with Cloudbreak"
    fi

    if [[ $(cb database create postgres --name hivedb --type HIVE --url jdbc:postgresql://$pgserver:5432/hive?ssl=true --db-username $pgusername --db-password $pgpwd) -eq 0 ]];then
        if [[ $(cb database list --output table | grep HIVE) -eq 0 ]];then
            add_log "Hive DB registered successfully with Cloudbreak"
        else
           exit_script "Failed to register Hive DB with Cloudbreak"
        fi 
    else
        exit_script "Failed to register Hive DB with Cloudbreak"
    fi

    if [[ $(cb database create postgres --name rangerdb --type RANGERDB --url jdbc:postgresql://$pgserver:5432/rangerdb?ssl=true --db-username $pgusername --db-password $pgpwd) -eq 0 ]];then
        if [[ $(cb database list --output table | grep HIVE) -eq 0 ]];then
            add_log "Ranger DB registered successfully with Cloudbreak"
        else
            exit_script "Failed to register Ranger DB with Cloudbreak"
        fi
    else
        exit_script "Failed to register Ranger DB with Cloudbreak"
    fi
    
    if [[ $(cb database create postgres --name nifiregdb --type REGISTRY --url jdbc:postgresql://$pgserver:5432/registry?ssl=true  --db-username $pgusername --db-password $pgpwd) -eq 0 ]];then
        if [[ $(cb database list --output table | grep HIVE) -eq 0 ]];then
            add_log "Registry DB registered successfully with Cloudbreak"
        else
            exit_script "Failed to register Registry DB with Cloudbreak"
        fi
    else
        exit_script "Failed to register Registry DB with Cloudbreak"
    fi
}

start_script
install_cb
register_db
