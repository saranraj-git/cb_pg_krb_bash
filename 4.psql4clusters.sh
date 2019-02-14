#!/usr/bin/env bash

: '
Create database for  Ambari, Druid, Hive, Oozie, Ranger, Registry, Superset
'

pgserver=" "
pghivedbname=" "
pgusername=" "
pgpwd=" "


sudo -i -u postgres psql -c 'CREATE DATABASE ambari'
sudo -i -u postgres psql -c 'CREATE DATABASE druid'
sudo -i -u postgres psql -c 'CREATE DATABASE hive'
sudo -i -u postgres psql -c 'CREATE DATABASE oozie'
sudo -i -u postgres psql -c 'CREATE DATABASE ranger'
sudo -i -u postgres psql -c 'CREATE DATABASE registry'
sudo -i -u postgres psql -c 'CREATE DATABASE superset'



cb database create postgres --name hive --type HIVE --url jdbc:postgresql://$pgserver:5432/$pghivedbname --db-username $pgusername --db-password $pgpwd
