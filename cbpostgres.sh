#!/usr/bin/env bash
: '
This script is meant for integrating the SSL Enabled Azure Postgres into Cloudbreak as its backend
Pre-requisites for executing this script
1. SSL cert for accessing the Azure postgres server must be placed under /var/lib/cloudbreak-deployment/
2. cert name has to renamed as database.crt  ( Eg: /var/lib/cloudbreak-deployment/database.crt )
3. Azure Postgres server details must be specified 
'

# Installing the Postgres Client
sudo yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-redhat10-10-2.noarch.rpm  
sudo yum install -y postgresql10 

# Getting the Postgres Server details
pgserver="cbreakpsql.postgres.database.azure.com" #eg: cbreakpsql.postgres.database.azure.com
pgserverport="5432"  # 5432
pgserverusername="psqladmin@postgresserver" # psqladmin@postgresserver
pgserverpassword="MyserverP@ssword" # MyserverP@ssword

# Set the Environment variables
export DATABASE_HOST=$pgserver
export DATABASE_PORT=$pgserverport
export DATABASE_USERNAME=$pgserverusername
export DATABASE_PASSWORD=$pgserverpassword

# Checking the required DB created i.e cbdb,periscopedb, uaadb and the cert exists in /var/lib/cloudbreak-deployment/cert/database.crt for SSL enabled Postgres Login
if [ ! -z "$pgserver" ] && [ ! -z "$pgserverport" ] && [ ! -z "$pgserverusername" ] && [ ! -z "$pgserverpassword" ] && [ -f /var/lib/cloudbreak-deployment/certs/database.crt ]; then
    echo "Checking the DB connectivity"


else
    echo "Please enter all these details Postgres_server_hostname/Port/Username/Pwd and cert exists in /var/lib/cloudbreak-deployment/certs/database.crt"
fi



# Updating the Profile file
cat >> /var/lib/cloudbreak-deployment/Profile << END
export DATABASE_HOST=$pgserver
export DATABASE_PORT=$pgserverport
export DATABASE_USERNAME=$pgserverusername
export DATABASE_PASSWORD=$pgserverpassword
export CB_DB_PORT_5432_TCP_ADDR=$DATABASE_HOST
export CB_DB_PORT_5432_TCP_PORT=$DATABASE_PORT
export CB_DB_ENV_USER=$DATABASE_USERNAME
export CB_DB_ENV_PASS=$DATABASE_PASSWORD
export CB_DB_ENV_DB=cbdb
export CB_JAVA_OPTS="-Dcb.db.env.ssl=true -Dcb.db.env.cert.file=database.crt"
export PERISCOPE_DB_TCP_ADDR=$DATABASE_HOST
export PERISCOPE_DB_TCP_PORT=$DATABASE_PORT
export PERISCOPE_DB_USER=$DATABASE_USERNAME
export PERISCOPE_DB_PASS=$DATABASE_PASSWORD
export PERISCOPE_DB_NAME=periscopedb
export PERISCOPE_DB_SCHEMA_NAME=public
export IDENTITY_DB_URL=$DATABASE_HOST:$DATABASE_PORT
export IDENTITY_DB_USER=$DATABASE_USERNAME
export IDENTITY_DB_PASS=$DATABASE_PASSWORD
export IDENTITY_DB_NAME=uaadb
END

# restarting the cbd using the command "cbd restart"
cd /var/lib/cloudbreak-deployment/ && cbd restart
