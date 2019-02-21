#!/usr/bin/env bash
: '

This script helps in launching the HDP/HDF clusters through cloudbreak

Components required:
1. Cloudbreak Instance details
2. Cloudbreak WebUI along with their credentials
3. Ambari Blueprint for HDP and HDF clusters
4. Azure ARM template file for provisioning the servers
'
cburl="https://52.237.208.167"
cbuser="cbadmin@example.com "
cbpasswd="Hadoop-123"

echo " ==== Installing the Cloudbreak Commandline utility ===="
curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /bin cb && chmod +x /bin/cb

echo " ==== Configuring Cloudbreak ===="
cb configure --server $cburl --username $cbuser --password $cbpasswd

echo " ==== Adding Ambari Blueprint to Cloudbreak ===="
cb blueprint create from-url --url https://raw.githubusercontent.com/svenugopal333/cb_az_prod/master/hdp31-data-science-spark2-v5.bp --name hdp31-data-science-spark2-v5

echo " ==== Getting the ARM template from the repository ==== "
wget https://raw.githubusercontent.com/svenugopal333/cb_az_prod/master/ARM_Template.json -O /var/lib/template.json 

echo " ==== Launching the cluster through Cloudbreak Cmd line === "
cb cluster create --cli-input-json /var/lib/template.json --name testclus1
