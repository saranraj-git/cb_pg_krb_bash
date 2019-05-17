#!/usr/bin/env bash
: '
This script helps in launching the HDP/HDF clusters through cloudbreak 
It needs to be executed on the Cloudbreak VM
Pre-requisites:
    -	T2 components (Cloudbreak, MIT KDC, Postgres) must be up and running.
    -	Cloudbreak integrated with Azure App Key of T3 subscription.
    -	Cloudbreak must be integrated with Postgres VM in T2.
    -	Repo for Ambari, HDP, HDP Utils, HDF, m-pack must be available in the Artifactory
    -	Cloudbreak Image need to be available in the blob storage and accessible to Cloudbreak VM
    -	Ambari Blueprint need to be stored in the artifactory accessible to Cloudbreak VM.
    -	Cloudbreak template need to be stored in the artifactory accessible to Cloudreak VM.
    -   epel release package need to be installed on this Cloudbreak VM
    -   python-pip package need to be available to install on this Cloudbreak VM
    -   Jinja2 CLI package need to be available for JSON parsing - using the command "pip install j2cli"
Input Parameters required for this script
    -	Cloudbreak Web UI (Tier2) – Username
    -	Cloudbreak Web UI (Tier2) - Password
    -	Ambari Blueprint URL for HDP cluster from Artifactory
    -	Ambari WebUI password
    -	Kerberos SPN (principal Name which has admin privileges in KDC)
    -	Kerberos SPN password
    -	Kerberos REALM name
    -	MIT-KDC VM - IPaddress
    -	HDP Repo URL from Artifactory
    -	HDP-Utils Repo URL from Artifactory
    -	HDP VDF URL from Artifactory
    -	Ambari Repo URL from Artifactory
    -	T3 VNet Name 
    -	T3 Subnet Name 
    -	T3 Network Resource Group Name
Components required:
1. Cloudbreak Instance details
2. Cloudbreak WebUI along with their credentials
3. Ambari Blueprint for HDP and HDF clusters
4. Azure ARM template file for provisioning the servers
5. Image catalog for the Instances being provisioned by cloudbreak
6. JQ file url - for JSON query processing
'
        # "http://artifactory/cb"
        # "https://cbvm.com"
          # "http://artifactory/jq"
Blueprint=$3  # "http://artifactory/var/lib/cloudbreak-deployment/hdpbp.json"         # "http://artifactory/hdpblueprint.json"
arm_url=$4    # "http://artifactory/var/lib/cloudbreak-deployment/t3arm.json"        # "http://artifactory/t3-arm-template.json"
cbusername=$1 # "cbadmin@example.com"  # This variable will be parametrized in the future release
cbpwd=$2      # "some secure pwd from DevOps "   #This variable will be parametrized in the future release

# Mandatory parameters for this script
cb_web_url="https://$(ip add | grep 'state UP' -A2 | head -n3 | awk '{print $2}' | cut -f1 -d'/' | tail -n1)"
cbutilpath=$1
jqurl=$2
cbusrname=$3
cbpwd=$4
cbjqtemplate=$5
cbjqtemplatepath="/tmp/.cbjqtmp.json"
cbinputtemplate=$6
cbinputtemplatepath="/tmp/.cbinputtemplate.json"
tstmp=$(date "+%Y%m%d%H%M%S")

start_script_0()
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

install_cb_jq_1()
{
    if [[ ! -f /bin/cb ]]; then
        if [[ $(wget $cbutilpath -O /bin/cb && chmod +x /bin/cb) -eq 0 ]];then
            add_log "CB utility downloaded successfully"
            if [[ $(cb configure --server $cb_web_url --username $cbusrname --password $cbpwd) -eq 0 ]];then
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
        add_log "JQ not installed on this machine"
        if [[ $(wget $jqurl -O /bin/jq && chmod +x /bin/jq) ]]; then
            add_log "Installed JQ version - $(jq --version)"
        else
            exit_script "Error installing JQ"
        fi
    else
        add_log "JQ already installed - $(jq --version)"
    fi
}

get_cb_template_2()
{
    if [[ $(wget $cbjqtemplate -O $cbjqtemplatepath) -eq 0 ]] && [[ $(wget $cbinputtemplate -O $cbinputtemplatepath) -eq 0 ]]; then
        [[ -s "$cbjqtemplatepath" ]] && add_log "Cloudbreak Template downloaded successfully with contents" || exit_script "Cloudbreak template downloaded as empty"
        [[ -s "$cbinputtemplatepath" ]] && add_log "Cloudbreak input Template downloaded successfully with contents" || exit_script "Cloudbreak input template downloaded as empty"
    else 
        exit_script "Unable to download Cloudbreak template from artifactory"
    fi
}


update_cb_input_template()
{
    #if [[ $(jq --arg val "$2" --arg key "$1" '.[$key] = $val' /tmp/input.json > /tmp/.mytmp) -eq 0 ]] && [[ $(mv /tmp/.mytmp /tmp/input.json -f) -eq 0 ]]; then
    if [[ $(jq --arg val "$2" --arg key "$1" '.[$key] = $val' $cbinputtemplatepath > /tmp/.mytmp) -eq 0 ]] && [[ $(mv /tmp/.mytmp $cbinputtemplatepath -f) -eq 0 ]]; then
        jq --arg key "$1" '.[$key]' $cbinputtemplatepath | cut -f2 -d'"' > /tmp/.aftr
            if [[ $2 == "$(cat /tmp/.aftr)" ]]; then
                add_log "Value of $1 updated in the input template successfully"
                rm -f /tmp/.aftr
                #export env_$1=$2
            else
                exit_script "Unable to update the value of $1 in the input template"
            fi 
    else 
        exit_script "Failed to update the value of $1"
    fi
}

#start_script_0
#cbinputtemplatepath="/tmp/input.json"
#update_cb_input_template "KDCIP" "1.2.3.4"



get_pipeline_param()
{
    export clusname="hdpcluster$tstmp"  #"testclusterhdp"
    export rgname=$clusname    # eg: "testclusterhdp"
    if [[ $(cb credential list | jq '.[].Name' | cut -f2 -d '"') -eq 0 ]]; then
        add_log "Azure Credential name registered with Cloudbreak - retrieved successfully"
        crname=$(cb credential list | jq '.[].Name' | cut -f2 -d '"')
        export t3cred=$crname   #"t3ddepcredentials"
    else 
        exit_script "Failed to get the Azure App Key registration name from Cloudbreak"
    fi
        
    
    export ambaripwd=$5  # "secure password for ambari through dev ops pipeline"
    export krbpwd=$6     # "secure password for kerberos through dev ops pipeline"
    export krbspn=$7     # kerberos service principal eg: ambari/admin@EXAMPLE.COM"
    export kdcip=$8      # Kerberos KDC IP
    export kadminip=$8   # Kerberos Kadmin IP
    export realm=$9      # Realm name
    export hdprepourl=$10  # HDP repo URL from artifactory eg: "http://public-repo-1.hortonworks.com/HDP/centos7/3.x/updates/3.1.0.0"
    export hdputilurl=$11 # HDP util repo url from artifactory eg: "http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.22/repos/centos7"
    export vdfurl=$12   # Version definition file from artifactory eg : "http://public-repo-1.hortonworks.com/HDP/centos7/3.x/updates/3.1.0.0/HDP-3.1.0.0-78.xml"
    export ambarirepourl=$13 # Ambari repo url from artifactory eg: "http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.7.3.0"
    export extambdb="myambaridb" #Ambari DB for the cluster
    export exthivedb="myhivedb"  #Hive DB for the cluster
    export extrangerdb="myrangerdb"  #ranger db for the cluster
    export imgcatalog="mycustomcatalog" #custom image catalog registered with cloudbreak
    export imguuid="c08fb21d-3fa6-46c1-4b41-7a4c2dd40b88"  #custom image UUID registered with cloudbreak
    export subnet=$14  # subnet id in Tier 3 to be utilized for the cluster eg:"xaea3sub2703191930"
    export nwrgname=$15 # network resource group name in Tier 3 eg : xaea3RG2703191929
    export vnet=$16  # Vnet in Tier 3"xaea3vnet2703191930"
    export pubkey=$17 # public key for ssh access to the T3 instances getting created 
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
            export bpname=$4   #"hdfs-hbase-yarn-grafana-logsearch"
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



#start_script
#install_Cb
#get_arm
#register_blueprint
#create_cluster
#get_cluster_status

