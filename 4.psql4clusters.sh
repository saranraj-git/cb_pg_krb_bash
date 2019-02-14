#!/usr/bin/env bash

pgserver=" "
pghivedbname=" "
pgusername=" "
pgpwd=" "

cb database create postgres --name hivedb --type HIVE --url jdbc:postgresql://$pgserver:5432/$pghivedbname --db-username $pgusername --db-password $pgpwd
