#!/usr/bin/env bash

: '
Create database for  Ambari, Druid, Hive, Oozie, Ranger, Registry, Superset
pgserver=" "
pghivedbname=" "
pgusername=" "
pgpwd=" "

'
# Installing the Postgres Client
sudo yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-redhat10-10-2.noarch.rpm  
sudo yum install -y postgresql10 


sudo -i -u postgres psql -c 'CREATE DATABASE ambari'
sudo -i -u postgres psql -c 'CREATE DATABASE druid'
sudo -i -u postgres psql -c 'CREATE DATABASE hive'
sudo -i -u postgres psql -c 'CREATE DATABASE oozie'
sudo -i -u postgres psql -c 'CREATE DATABASE ranger'
sudo -i -u postgres psql -c 'CREATE DATABASE registry'
sudo -i -u postgres psql -c 'CREATE DATABASE superset'


cb database create postgres --name hive  --type HIVE --url jdbc:postgresql://testsrj.field.hortonworks.com:5432/hive?ssl=true --db-username cbadmin --db-password Hadoop-123


cb database create postgres --name hive --type HIVE --url jdbc:postgresql://$pgserver:5432/$pghivedbname?ssl=true --db-username $pgusername --db-password $pgpwd
