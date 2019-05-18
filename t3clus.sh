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
 # "http://artifactory/var/lib/cloudbreak-deployment/hdpbp.json"         # "http://artifactory/hdpblueprint.json"

# Mandatory parameters for this script

# CB vm related details

    #cb_web_url="https://$(ip add | grep 'state UP' -A2 | head -n3 | awk '{print $2}' | cut -f1 -d'/' | tail -n1)"
cb_web_url="https://$1"  # $1 Cloudbreak VM IP address
cbutilpath="http://172.26.201.244/cb"   #  $2 CB file url from artifactory
jqurl="http://172.26.201.244/jq"   #  $3 JQ file url from artifactory
cbusrname=$4
cbpwd=$5

#input files 
tstmp=$(date "+%Y%m%d%H%M%S")
clusname="hdp$tstmp"  #"Name of the cluster"

cbjqtemplate="http://172.26.201.244/jqtemplate" #$6
cbjqtemplatepath="/tmp/.cbjqtmp_$tstmp.json"

cbinputtemplate="http://172.26.201.244/inptemplate" #$7
cbinputtemplatepath="/tmp/.cbinputtemplate_$tstmp.json"

cb_finaltemplate="/tmp/.cbfinaltemplate_$tstmp.json"

#blueprint url
bp_url="http://172.26.201.244/hdpbp.json" # $8
bp_path="/tmp/.hdpbp_$tstmp.json"

#======= Template params from Pipeline ================
s_amb_pwd=$9
s_krb_princ=${10}
s_krb_pwd=${11}
s_kdc_ip=${12}
s_realm=${13}
s_hdp_repo=${14}
s_hdp_util_repo=${15}
s_vdf_url=${16}
s_ambari_repo=${17}
s_subnet=${18}
s_nwrg=${19}
s_vnet=${20}
s_pubkey=${21}

#==================================

start_script_0()   # Testing completed
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

exit_script() # Testing Completed
{
    add_log "Error !!! $1 !!!"
    add_log "Exiting the script execution"
    exit 1
}

install_cb_jq_1() # CB Configure need to be tested
{
    if [[ ! -f /bin/cb ]]; then
        if [[ $(wget $cbutilpath -O /bin/cb) -eq 0 ]] && [[ $(chmod +x /bin/cb) -eq 0 ]];then
            add_log "CB utility downloaded successfully"
            if [[ $(cb configure --server $cb_web_url --username $cbusrname --password $cbpwd) -eq 0 ]] && [[ $(cb cluster list) -eq 0 ]];then
                add_log "CB configured succcessfully with Cloudbreak VM"
            else
                exit_script "Unable to configure CB Utility with Cloudbreak"
            fi
        else
            exit_script "Failed to Download CB from the internet"
        fi
    else
        add_log "CB file already exists"
        if [[ $(cb configure --server $cb_web_url --username $cbusername --password $cbpwd) -eq 0 ]] && [[ $(cb cluster list) -eq 0 ]];then
            add_log "CB configured succcessfully with Cloudbreak VM"
        else
            exit_script "Unable to configure CB Utility with Cloudbreak"
        fi
    fi 
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
}

get_cb_template_2() # Testing Completed
{
    if [[ $(wget $cbjqtemplate -O $cbjqtemplatepath) -eq 0 ]] && [[ $(wget $cbinputtemplate -O $cbinputtemplatepath) -eq 0 ]]; then
        [[ -s "$cbjqtemplatepath" ]] && add_log "Cloudbreak Template downloaded successfully with contents" || exit_script "Cloudbreak template downloaded as empty"
        [[ -s "$cbinputtemplatepath" ]] && add_log "Cloudbreak input Template downloaded successfully with contents" || exit_script "Cloudbreak input template downloaded as empty"
    else 
        exit_script "Unable to download Cloudbreak template from artifactory"
    fi
}


update_cb_input_template() # Testing completed
{
    #if [[ $(jq --arg val "$2" --arg key "$1" '.[$key] = $val' /tmp/input.json > /tmp/.mytmp) -eq 0 ]] && [[ $(mv /tmp/.mytmp /tmp/input.json -f) -eq 0 ]]; then
    if [[ $(jq --arg val "$2" --arg key "$1" '.[$key] = $val' $cbinputtemplatepath > /tmp/.mytmp) -eq 0 ]] && [[ $(mv /tmp/.mytmp $cbinputtemplatepath -f) -eq 0 ]]; then
        jq --arg key "$1" '.[$key]' $cbinputtemplatepath | cut -f2 -d'"' > /tmp/.aftr
            if [[ $2 == "$(cat /tmp/.aftr)" ]]; then
                add_log "Value of $1 updated in the input template successfully"
                rm -f /tmp/.aftr
            else
                exit_script "Unable to update the value of $1 in the input template"
            fi 
    else 
        exit_script "Failed to update the value of $1"
    fi
}


get_pipeline_param_3() # Testing completed 
{
    add_log "Updating the pipeline parameters to the input file"
    
    update_cb_input_template "CLUSNAME" $clusname
    export HWX_CLUSNAME="$clusname"    # eg: "mycluster name in T3"
    update_cb_input_template "RGNAME" $clusname
    export HWX_RGNAME="$clusname"    # eg: "my resource group name in T3"

    update_cb_input_template "AMBARIPWD"  "$1"
    export HWX_AMBARIPWD="$1"  # $5  # "secure password for ambari through dev ops pipeline"
    
    update_cb_input_template "KRBSPN" "$2"
    export HWX_KRBSPN="$2" # $7     # kerberos service principal eg: ambari/admin@EXAMPLE.COM"
    
    update_cb_input_template "KRBPWD" "$3"
    export HWX_KRBPWD="$3" # $6     # "secure password for kerberos through dev ops pipeline"
    
    update_cb_input_template "KDCIP" "$4"
    export HWX_KDCIP="$4" # $8      # Kerberos KDC IP
    
    update_cb_input_template "KADMINIP" "$4" 
    export HWX_KADMINIP="$4" # $8   # Kerberos Kadmin IP
    
    update_cb_input_template "REALM" "$5"
    export HWX_REALM="$5"  # $9      # Realm name
    
    update_cb_input_template "HDPREPOURL" "$6"
    export HWX_HDPREPOURL="$6"  # HDP repo URL from artifactory eg: "http://public-repo-1.hortonworks.com/HDP/centos7/3.x/updates/3.1.0.0"
    
    update_cb_input_template "HDPUTILURL" "$7"
    export HWX_HDPUTILURL="$7" # HDP util repo url from artifactory eg: "http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.22/repos/centos7"
    
    update_cb_input_template "VDFURL" "$8"
    export HWX_VDFURL="$8"   # Version definition file from artifactory eg : "http://public-repo-1.hortonworks.com/HDP/centos7/3.x/updates/3.1.0.0/HDP-3.1.0.0-78.xml"
    
    update_cb_input_template "AMBARIREPOURL" "$9"
    export HWX_AMBARIREPOURL="$9" # Ambari repo url from artifactory eg: "http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.7.3.0"
    
    update_cb_input_template "SUBNET" "${10}"
    export HWX_SUBNET="${10}"  # subnet id in Tier 3 to be utilized for the cluster eg:"xaea3sub2703191930"
    
    update_cb_input_template "NWRGNAME" "${11}"
    export HWX_NWRGNAME="${12}" # network resource group name in Tier 3 eg : xaea3RG2703191929
    
    update_cb_input_template "VNET" "${12}"
    export HWX_VNET="${12}"  # Vnet in Tier 3"xaea3vnet2703191930"
    
    update_cb_input_template "PUBKEY" "${13}"
    export HWX_PUBKEY="${13}" # public key for ssh access to the T3 instances getting created 
}

start_script_0
install_cb_jq_1
get_cb_template_2
# get_pipeline_param "superAmbPWD" "admin/ambari" "superKRBPwd" "kdc.ip.address" "ddep.com" "http://hdprepo.com" "http://hdputilrepo" "http://vdfurl" "http://ambarirepo" "t3subnet" "t3NwRG" "t3vnet" "pubkey_securedone"
get_pipeline_param_3 "$s_amb_pwd" "$s_krb_princ" "$s_krb_pwd" "$s_kdc_ip" "$s_realm" "$s_hdp_repo" "$s_hdp_util_repo" "$s_vdf_url" "$s_ambari_repo" "$s_subnet" "$s_nwrg" "$s_vnet" "$s_pubkey" 

from_cb_util()  # requires Testing on cb machine
{
    if [[ $(cb credential list | jq '.[].Name' | cut -f2 -d '"') -eq 0 ]]; then
        add_log "Azure Credential name registered with Cloudbreak - retrieved successfully"
        crname=$(cb credential list | jq '.[].Name' | cut -f2 -d '"')
        update_cb_input_template "T3CRED" $crname
        export HWX_T3CRED=$crname   #"some azure reg name"
    else 
        exit_script "Failed to get the Azure App Key registration name from Cloudbreak"
    fi
    
    if [[ $(cb database list) -eq 0 ]]; then
        add_log "Database retrieved successfully"
        export HWX_EXTAMBDB="myambaridb" #Ambari DB for the cluster
        update_cb_input_template "EXTAMBARIDB" 

        # export HWX_EXTHIVEDB="myhivedb"  #Hive DB for the cluster
        # update_cb_input_template "EXTHIVEDB" $1

        # export HWX_EXTRANGERDB="myrangerdb"  #ranger db for the cluster
        # update_cb_input_template "EXTRANGERDB" $2
    else
	    exit_script "Unable to retrieve external database name registered with Cloudbreak"
    fi


    if [[ $(cb imagecatalog list | jq '.[].') -eq 0 ]]; then
        export HWX_IMGCATALOG="mycustomcatalog" #custom image catalog registered with cloudbreak
        update_cb_input_template
        add_log ""

        export HWX_IMGUUID="c08fb21d-3fa6-46c1-4b41-7a4c2dd40b88"  #custom image UUID registered with cloudbreak
        update_cb_input_template
        add_log ""

    else
        exit_script "Unable to retrieve Image catalog from Cloudbreak"
    fi
}

get_bp() 
{    
    if [[ $(wget "$bp_url" -O "$bp_path") -eq 0 ]] && [[ -s "$bp_path" ]]; then
        add_log "Ambari Blueprint successfully downloaded under $bp_path"
    else
        exit_script "Failed to download Ambari Blueprint from Artifactory"
    fi
}

register_blueprint()
{
    add_log "Registering custom HDP Blueprint with Cloudbreak"
    if [[ $(cb blueprint create from-file --name $clusname --file $bp_path) -eq 0 ]]; then
        add_log "Custom HDP Blueprint registered successfully with Cloudbreak"
        add_log "Validating the Blueprint registration using cb command"
        val=$(cb blueprint list | jq '.[] | {"Name"}' | grep "Name" | cut -f4 -d'"' | grep $clusname)
        if [[ $val ]]; then
            add_log "Blueprint registered successfully (Blueprint name - $val)"
            export HWX_BPNAME="$clusname"   #"hdfs-hbase-yarn-grafana-logsearch" 
            update_cb_input_template "BPNAME" "$clusname"
        else
            exit_script "Blueprint validation failed with CB"
        fi
    else 
        exit_script "Custom HDP Blueprint registration failed"
    fi
}

merge_template()
{
    if [[ $(cat $cbinputtemplatepath | jq -f $cbjqtemplatepath > $cb_finaltemplate) -eq 0 ]] && [[ -s $cb_finaltemplate ]]; then
	    add_log "Successfully merged the input template with Cloudbreak Template"
    else
	    exit_script "Failed to merge the input template with Cloudbreak Template"
    fi
}

create_cluster()
{
    if [[ $(cb cluster create --cli-input-json $cb_finaltemplate --name $clusname) -eq 0 ]]; then
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
    st=$(cb cluster describe --name $clusname | jq '.statusReason')
    add_log "Cluster status - $st"
        if [ $st == "Cluster creation finished." ] || [ $st == "Failed" ]; then
            fst=$(cb cluster describe --name $clusname | jq '.cluster.status')
            if [[ $fst =~ "AVAILABLE" ]];then
                $status="Finished"
                add_log "Cluster creation completed"
                amb=$(cb cluster describe --name $clusname | grep -i ambariServerUrl)
                add_log "Cluster status is AVAILABLE"
                add_log "Ambari Server URL - $amb"
            fi
            if [[ $fst =~ "FAILED" ]];then
                $status="FAILED"
                exit_script "Cluster creation Failed - check the logs in the Cloudbreak VM using the command cbd logs cloudbreak"
            fi
        fi
    done
}

cleanup()
{

}

0_start_script
1_install_cb_jq
