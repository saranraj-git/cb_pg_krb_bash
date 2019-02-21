#!/usr/bin/env bash

: '

This script helps in integrating the Postgres databases (for HDP/HDF clusters) to Cloudbreak:

It requires the following as input:

1. Postgres DB server FQDN
2. DB 

'
pgserver=" "
pgusername=" "
pgpwd=" "


cb configure --server https://52.237.208.167 --username cbadmin@example.com --password "Hadoop-123"
cb database create postgres --name myambari --type AMBARI --url jdbc:postgresql://cbpostgres.postgres.database.azure.com:5432/ambari?ssl=true  --db-username cbpsqladmin@cbpostgres --db-password Hadoop-123
cb database create postgres --name myhive --type HIVE --url jdbc:postgresql://cbpostgres.postgres.database.azure.com:5432/hive?ssl=true  --db-username cbpsqladmin@cbpostgres --db-password Hadoop-123
cb database create postgres --name myranger --type RANGER --url jdbc:postgresql://cbpostgres.postgres.database.azure.com:5432/rangerdb?ssl=true  --db-username cbpsqladmin@cbpostgres --db-password Hadoop-123
cb database create postgres --name hive  --type HIVE --url jdbc:postgresql://testsrj.field.hortonworks.com:5432/hive?ssl=true --db-username cbadmin --db-password Hadoop-123
cb database create postgres --name hive --type HIVE --url jdbc:postgresql://$pgserver:5432/$pghivedbname?ssl=true --db-username $pgusername --db-password $pgpwd
