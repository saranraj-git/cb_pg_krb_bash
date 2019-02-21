#!/usr/bin/env bash

: '

This script helps in integrating the Postgres databases (for HDP/HDF clusters) to Cloudbreak:

It requires the following as input:

1. Postgres DB server FQDN
2. DB Username and password
3. Cloudbreak deployer VM fqdn along with the username and password for Cloudbreak WebUI

'
pgserver="cbpostgres.postgres.database.azure.com"
pgusername="cbpsqladmin@cbpostgres"
pgpwd="Hadoop-12345"
cburl="https://52.237.208.167"
cbuser="cbadmin@example.com "
cbpasswd="Hadoop-123"
curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /bin cb && chmod +x /bin/cb
cb configure --server $cburl --username $cbuser --password $cbpasswd
cb database create postgres --name rangerdb --type AMBARI --url jdbc:postgresql://$pgserver:5432/ambari?ssl=true  --db-username $pgusername --db-password $pgpwd
cb database create postgres --name hivedb --type HIVE --url jdbc:postgresql://$pgserver:5432/hive?ssl=true --db-username $pgusername --db-password $pgpwd
cb database create postgres --name rangerdb --type RANGERDB --url jdbc:postgresql://$pgserver:5432/rangerdb?ssl=true --db-username $pgusername --db-password $pgpwd
