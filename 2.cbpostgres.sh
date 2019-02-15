#!/usr/bin/env bash
: '
This script is meant for integrating the SSL Enabled Azure Postgres into Cloudbreak as its backend

NOTE: Script needs to be executed ONLY on the CLOUDBREAK Instance !!!

Postgres credentials given in this script must have the permissions to create database remotely

Parameters required for running this script
    1. Postgres Server FQDN
    2. Postgres Server Port number
    3. Postgres Server Username
    4. Postgres Server Password
    5. URL of the Postgres Instance - Client Certificate

Script execution procedure: (Script parameters must be in the same order)

Syntax :

./cbpostgres.sh <Postgres Server FQDN>  <Postgres Server Port> <Postgres Username> <Postgres Password> <PG ClientcertURL>

Eg:

./cbpostgres.sh myPGServer.com 5432 cbadmin cbP@ssw0rd http://certrepo/pgClientCert.crt

'
if [ $# -eq 5 ]; then

# Installing the Postgres Client on this machine to check the database is created
sudo yum install -y https://download.postgresql.org/pub/repos/yum/10/redhat/rhel-7-x86_64/pgdg-redhat10-10-2.noarch.rpm  
sudo yum install -y postgresql10 

# Getting the Postgres Server details
pgserver="$1" #eg: cbreakpsql.postgres.database.azure.com
pgserverport="$2"  # 5432
pgserverusername="$3" # psqladmin@postgresserver
pgserverpassword="$4" # MyserverP@ssword

# Set the Environment variables
export DATABASE_HOST=$pgserver
export DATABASE_PORT=$pgserverport
export DATABASE_USERNAME=$pgserverusername
export DATABASE_PASSWORD=$pgserverpassword

# Placing the Postgres Client certificate at the right location
wget $5 -O /var/lib/cloudbreak-deployment/certs/database.crt && chmod 400 /var/lib/cloudbreak-deployment/certs/database.crt 

# Checking the postgres server to see if the database is created
: '

psql 

'

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

else
    echo -e "This script requires 5 arguments in this order :"
    echo -e "Example \n \n ./cbpostgres.sh myPGServer.com 5432 cbadmin cbP@ssw0rd http://certrepo/pgClientCert.crt"
    exit 1;
fi



: '
Future Enhancements of this script

sudo -i -u postgres psql -c 'CREATE DATABASE cbdb'
sudo -i -u postgres psql -c 'CREATE DATABASE uaadb'
sudo -i -u postgres psql -c 'CREATE DATABASE periscopedb'
sudo -i -u postgres psql -c "CREATE USER cbadmin WITH PASSWORD $4;"
sudo -i -u postgres psql -c 'grant all privileges on database cbdb to "$3"'
sudo -i -u postgres psql -c 'grant all privileges on database periscopedb to "$3"'
sudo -i -u postgres psql -c 'grant all privileges on database uaadb to "$3"'
'
