#!/bin/bash
: '
This script helps in integrating the Postgres databases (for HDP/HDF clusters) to Cloudbreak:
It requires the following parameters in the same order:
Parameter 1 : Postgres DB - username
Parameter 2 : Postgres DB - password
Parameter 3 : CB utility - Artifactory URL to download
Parameter 4 : Cloudbreak VM IP address from T2
Parameter 5 : Cloudbreak Web UI - username
Parameter 6 : Cloudbreak Web UI - Password
'
# Getting the inputs as parameter for Cloudbreak WebUI and postgres server 
pgserver=$(ip add | grep 'state UP' -A2 | head -n3 | awk '{print $2}' | cut -f1 -d'/' | tail -n1)
pgusername="postgres"   #  $1       Eg: "cbadmin or postgres"
pgpwd="Hadoop-123"        #  $2       some secure pwd from DevOps
cbutilpath="https://cb333.blob.core.windows.net/testcatalog/cb"    #  $3 artifactory url for CB utility
cbip="10.50.0.4"  #  $4          
cb_web_url="https://$cbip"
cbusrname="cloudbreak@devddep.com" # $5  "cloudbreak@devddep.com "
cbpwd="Westp@c"   #  $6     #some secure pwd from DevOps
tstmp=$(date "+%Y%m%d%H%M%S")
ambaridbname="ambari$tstmp"
hivedbname="hive$tstmp"
rangerdbname="ranger$tstmp"
registrydbname="registry$tstmp"

start_script_0()
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

# Installing and configuring CB utility 
install_cb_1() # CB Configure need to be tested
{
    if [[ ! -f /bin/cb ]]; then
        if [[ $(wget $cbutilpath -O /bin/cb) -eq 0 ]] && [[ $(chmod +x /bin/cb) -eq 0 ]];then
            add_log "CB utility downloaded successfully"
            if [[ $(cb configure --server "$cb_web_url" --username "$cbusrname" --password "$cbpwd") -eq 0 ]];then
				if [[ $(cb credential list | jq '.[].Name' | cut -f2 -d '"') -eq 0 ]]; then
					crname=$(cb credential list | jq '.[].Name' | cut -f2 -d '"')
					if [[ $crname ]];then
						add_log "CB configured succcessfully with Cloudbreak VM"
					else
						exit_script "Unable to configure CB Utility with Cloudbreak"
					fi
				else 
					exit_script "Unable to configure CB Utility with Cloudbreak"
				fi
                
            else
                exit_script "Unable to configure CB Utility with Cloudbreak"
            fi
        else
            exit_script "Failed to Download CB from the internet"
        fi
    else
        add_log "CB file already exists"
        if [[ $(cb configure --server "$cb_web_url" --username "$cbusrname" --password "$cbpwd") -eq 0 ]];then
            if [[ $(cb credential list | jq '.[].Name' | cut -f2 -d '"') -eq 0 ]]; then
					crname=$(cb credential list | jq '.[].Name' | cut -f2 -d '"')
					if [[ $crname ]];then
						add_log "CB configured succcessfully with Cloudbreak VM"
					else
						exit_script "Unable to configure CB Utility with Cloudbreak"
					fi
				else 
					exit_script "Unable to configure CB Utility with Cloudbreak"
			fi
        else
            exit_script "Unable to configure CB Utility with Cloudbreak"
        fi
    fi 

    : '
    add_log "Checking JQ ...."
    if [[ ! -f /bin/jq ]]; then
        add_log "JQ not installed on this machine"
        if [[ $(wget $jqurl -O /bin/jq) ]] && [[ $(chmod +x /bin/jq) ]]; then
            add_log "Installed JQ version - $(jq --version)"
        else
            exit_script "Error installing JQ"
        fi
    else
        add_log "JQ already installed - $(jq --version)"
    fi
    '

}

create_db_2()
{
	 echo "CREATE DATABASE $ambaridbname;" > /tmp/.dbcmd.txt
	 echo "CREATE DATABASE $hivedbname;" >> /tmp/.dbcmd.txt
	 echo "CREATE DATABASE $rangerdbname;" >> /tmp/.dbcmd.txt
	 echo "CREATE DATABASE $registrydbname;" >> /tmp/.dbcmd.txt
     sudo -i -u postgres psql -c "\i /tmp/.dbcmd.txt"
        ambval=$(sudo -i -u postgres psql -c "\l+" | grep "$ambaridbname" | cut -f1 -d"|")
		hiveval=$(sudo -i -u postgres psql -c "\l+" | grep "$hivedbname" | cut -f1 -d"|")
		rangerval=$(sudo -i -u postgres psql -c "\l+" | grep "$rangerdbname" | cut -f1 -d"|")
		registryval=$(sudo -i -u postgres psql -c "\l+" | grep "$registrydbname" | cut -f1 -d"|")
        [[ $ambval ]] && add_log "$ambaridbname database created successfully" || exit_script "Unable to create/validate $ambaridbname database"
		[[ $hiveval ]] && add_log "$hivedbname database created successfully" || exit_script "Unable to create/validate $hivedbname database"
		[[ $rangerval ]] && add_log "$rangerdbname database created successfully" || exit_script "Unable to create/validate $rangerdbname database"
		[[ $registryval ]] && add_log "$registrydbname database created successfully" || exit_script "Unable to create/validate $registrydbname database"
    
}
# Register External Postgres DB created for HDP/HDF clusters with Cloudbreak
register_db_3()
{
    if [[ $(cb database create postgres --name $ambaridbname --type AMBARI --url jdbc:postgresql://$pgserver:5432/$ambaridbname --db-username $pgusername --db-password $pgpwd) -eq 0 ]]; then
        
            cbambdb=$(cb database list -output table | grep $ambaridbname | cut -f2 -d"|")
            if [[ $cbambdb ]];then 
                add_log "Ambari DB - $ambaridbname registered successfully with Cloudbreak"
            else
                exit_script "Unable to validate Ambari DB - $ambaridbname from cloudbreak"
            fi
        
    else
        exit_script "Failed to register Ambari DB with Cloudbreak"
    fi

    if [[ $(cb database create postgres --name $hivedbname --type HIVE --url jdbc:postgresql://$pgserver:5432/$hivedbname --db-username $pgusername --db-password $pgpwd) -eq 0 ]];then
        
            cbhivedb=$(cb database list -output table | grep $hivedbname | cut -f2 -d"|")
            if [[ $cbhivedb ]];then 
                add_log "Hive DB - $hivedbname registered successfully with Cloudbreak"
            else
                exit_script "Unable to validate Hive db - $hivedbname from cloudbreak"
            fi
        
    else
        exit_script "Failed to register Hive DB with Cloudbreak"
    fi

    if [[ $(cb database create postgres --name $rangerdbname --type RANGERDB --url jdbc:postgresql://$pgserver:5432/$rangerdbname --db-username $pgusername --db-password $pgpwd) -eq 0 ]];then
        
            cbrangerdb=$(cb database list -output table | grep $rangerdbname | cut -f2 -d"|")
            if [[ $cbrangerdb ]];then 
                add_log "Ranger DB - $rangerdbname registered successfully with Cloudbreak"
            else
                exit_script "Unable to validate Ranger db - $rangerdbname from cloudbreak"
            fi
        
    else
        exit_script "Failed to register Ranger DB with Cloudbreak"
    fi
    
    if [[ $(cb database create postgres --name $registrydbname --type REGISTRY --url jdbc:postgresql://$pgserver:5432/$registrydbname  --db-username $pgusername --db-password $pgpwd) -eq 0 ]];then
        
            cbregistrydb=$(cb database list -output table | grep $registrydbname | cut -f2 -d"|")
            if [[ $cbregistrydb ]];then 
                add_log "Registry DB - $registrydbname registered successfully with Cloudbreak"
            else
                exit_script "Unable to validate Registry db - $registrydbname from cloudbreak"
            fi
        
    else
        exit_script "Failed to register Registry DB with Cloudbreak"
    fi
}


start_script_0
install_cb_1
create_db_2
register_db_3
