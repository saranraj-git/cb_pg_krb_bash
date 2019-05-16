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
6. JQ file url - for JSON query processing

Pre-requisites:

•	T2 components (Cloudbreak, MIT KDC, Postgres) must be up and running.
•	Cloudbreak integrated with Azure App Key of T3 subscription.
•	Cloudbreak must be integrated with Postgres VM in T2.
•	Repo for Ambari, HDP, HDP Utils, HDF, m-pack must be available in the Artifactory
•	Cloudbreak Image need to be available in the blob storage and accessible to Cloudbreak VM
•	Ambari Blueprint need to be stored in the artifactory accessible to Cloudbreak VM.
•	Cloudbreak template need to be stored in the artifactory accessible to Cloudreak VM.

In T3 DevOps Pipeline:

•	Hwx bash script for Postgres DB Registration with Cloudbreak requires the following parameters as input. (Need to be executed on Postgres VM in T2)
        o	Postgres DB - UserName
        o	Postgres DB - password
        o	CB utility file url from Artifactory
        o	Cloudbreak VM – IP address
        o	Cloudbreak Web UI – username
        o	Cloudbreak Web UI – Password
        o	JQ file URL from Artifactory
•	Hwx bash script for HDP Cluster Creation requires the following mandatory parameters as input. (Need to be executed on Cloudbreak VM in T2)
        o	Cloudbreak Web UI (Tier2) – Username
        o	Cloudbreak Web UI (Tier2) - Password
        o	Ambari Blueprint URL for HDP cluster from Artifactory
        o	Ambari WebUI password
        o	Kerberos SPN (principal Name which has admin privileges in KDC)
        o	Kerberos SPN password
        o	Kerberos REALM name
        o	MIT-KDC VM - IPaddress
        o	HDP Repo URL from Artifactory
        o	HDP-Utils Repo URL from Artifactory
        o	HDP VDF URL from Artifactory
        o	Ambari Repo URL from Artifactory
        o	T3 VNet Name (eg: xaea3vnet2703191930)
        o	T3 Subnet Name (eg: xaea3sub2703191930)
        o	T3 Network Resource Group Name (eg: xaea3RG2703191929)
•	Hwx bash script for HDF Cluster Creation requires the following mandatory parameters as input. (Need to be executed on Cloudbreak VM in T2)
        o	Cloudbreak Web UI (Tier2) – Username
        o	Cloudbreak Web UI (Tier2) - Password
        o	Ambari Blueprint URL for HDF cluster from Artifactory
        o	Ambari WebUI password
        o	Kerberos SPN (principal Name which has admin privileges in KDC)
        o	Kerberos SPN password
        o	Kerberos REALM name
        o	MIT-KDC VM - IPaddress
        o	HDF Repo URL from Artifactory
        o	HDF – Ambari mpack URL from Artifactory
        o	Ambari Repo URL from Artifactory
        o	T3 VNet Name (eg: xaea3vnet2703191930)
        o	T3 Subnet Name (eg: xaea3sub2703191930)
        o	T3 Network Resource Group Name (eg: xaea3RG2703191929)



'
#cbutilpath=$1        # "http://artifactory/cb"
cb_web_url="https://$(ip add | grep 'state UP' -A2 | head -n3 | awk '{print $2}' | cut -f1 -d'/' | tail -n1)"        # "https://cbvm.com"
#jqurl=$3             # "http://artifactory/jq"
Blueprint=$3  # "http://artifactory/var/lib/cloudbreak-deployment/hdpbp.json"         # "http://artifactory/hdpblueprint.json"
arm_url=$4    # "http://artifactory/var/lib/cloudbreak-deployment/t3arm.json"        # "http://artifactory/t3-arm-template.json"
cbusername=$1 # "cbadmin@example.com"  # This variable will be parametrized in the future release
cbpwd=$2      # "some secure pwd from DevOps "   #This variable will be parametrized in the future release


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

install_Cb()
{
    if [[ ! -f /bin/cb ]]; then
    # https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz
        if [[ $(wget $cbutilpath -O /bin/cb && chmod +x /bin/cb) -eq 0 ]];then
            add_log "CB utility downloaded successfully"
            if [[ $(cb configure --server $cb_web_url --username $cbusername --password $cbpwd) -eq 0 ]];then
                add_log "CB configured succcessfully with Cloudbreak VM"
            else
                exit_script "Unable to configure CB Utility with Cloudbreak"
            fi
        else
            exit_script "Failed to Download CB from the internet"
        fi
    else
        add_log "CB file already exists"
        if [[ $(cb configure --server $cb_web_url --username $cbusername --password $cbpwd) -eq 0 ]];then
            add_log "CB configured succcessfully with Cloudbreak VM"
        else
            exit_script "Unable to configure CB Utility with Cloudbreak"
        fi
    fi 
    add_log "Checking JQ ...."
    if [[ ! -f /bin/jq ]]; then
        if [[ $(wget $jqurl -O /bin/jq && chmod +x /bin/jq) ]]; then
            add_log "Installed JQ version - $(jq --version)"
        else
            exit_script "Error installing JQ"
        fi
    else
        add_log "JQ already installed - $(jq --version)"
    fi
}

get_arm()
{
    if [[ -f $arm_url ]]; then
        add_log "ARM template found in /var/lib/cloudbreak-deployment/t3arm.json"
    else
        exit_script "ARM template not found in /var/lib/cloudbreak-deployment/t3arm.json"
    fi
    
    if [[ -f $Blueprint ]]; then
        add_log "Blueprint found in /var/lib/cloudbreak-deployment/hdpbp.json"
    else
        exit_script "Blueprint not found in /var/lib/cloudbreak-deployment/hdpbp.json"
    fi
}

register_blueprint()
{
    add_log "Registering custom HDP Blueprint with Cloudbreak"
    if [[ $(cb blueprint create from-file --name myhdpbp --file $Blueprint) -eq 0 ]]; then
        add_log "Custom HDP Blueprint registered successfully"
        add_log "Validating the Blueprint registration using cb command"
        val=$(cb blueprint list | jq '.[] | {"Name"}' | grep "Name" | cut -f4 -d'"' | grep myhdpbp)
        if [[ $val ]]; then
            add_log "Blueprint registered successfully (Blueprint name - $val)"
        else
            exit_script "Blueprint validation failed with CB"
        fi
    else 
        exit_script "Custom HDP Blueprint registration failed"
    fi
}

create_cluster()
{
    if [[ $(cb cluster create --cli-input-json $arm_url --name myhdp3cluster) -eq 0 ]]; then
        add_log "Cluster creation command submitted successfully"
    else
        exit_script "Cluster creation command failed"
    fi
}

get_cluster_status()
{
    status="Initial"
    add_log "Checking Cluster deployment status....."
    while [ $status == "Initial" ]
    do
    sleep 10s
    st=$(cb cluster describe --name myhdp3cluster | jq '.statusReason')
    add_log "Cluster status - $st"
        if [ $st == "Cluster creation finished." ] || [ $st == "Failed" ]; then
            add_log "Cluster creation completed"
            fst=$(cb cluster describe --name myhdp3cluster | jq '.cluster.status')
            if [[ $fst =~ "AVAILABLE" ]];then
                $status="Finished"
                amb=$(cb cluster describe --name myhdp3cluster | grep -i ambariServerUrl)
                add_log "$amb"
                add_log "Cluster status is AVAILABLE"
            fi
        fi
    done
}



start_script
install_Cb
get_arm
register_blueprint
create_cluster
get_cluster_status
