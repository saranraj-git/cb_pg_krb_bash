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
cburl="https://52.237.208.167"
cbuser="cbadmin@example.com "
cbpasswd="Hadoop-123"

echo " ==== Installing the Cloudbreak Commandline utility ===="
curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /bin cb && chmod +x /bin/cb

echo " ==== Configuring Cloudbreak ===="
cb configure --server $cburl --username $cbuser --password $cbpasswd

echo " ==== Adding Ambari Blueprint to Cloudbreak ===="
cb blueprint create from-url --url https://raw.githubusercontent.com/svenugopal333/cb_az_prod/master/hdp31-data-science-spark2-v5.bp --name srj1

echo " ==== Getting the ARM template from the repository ==== "
wget https://raw.githubusercontent.com/svenugopal333/cb_az_prod/master/ARM_Template.json -O /var/lib/template.json 

echo " ==== Adding Image catalog to Cloudbreak ===== "
cb imagecatalog create --url https://raw.githubusercontent.com/svenugopal333/cb_az_prod/master/ImageCatalog.json --name baseimage
cb imagecatalog set-default --name baseimage

echo " ==== Launching the cluster through Cloudbreak Cmd line === "
cb cluster create --cli-input-json /var/lib/template.json --name testclus1

echo " ==== Checking the cluster status === "
cb cluster describe --name testclus1  | grep status

echo " ==== Getting the Ambari URL ===="
cb cluster describe --name testclus1 | grep ambariServerUrl


