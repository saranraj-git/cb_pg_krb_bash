#!/usr/bin/env bash
: '
This script is meant for integrating the SSL Enabled Azure Postgres into Cloudbreak as its backend
Parameters required for running this script
    1. Postgres Server FQDN
    2. Postgres Server Port number
    3. Postgres Server Username
    4. Postgres Server Password
    5. URL of the Postgres server Client Certificate

Script execution procedure:
Eg:

./cbpostgres.sh myPGServer.com 5432 cbadmin cbP@ssw0rd http://certrepo/pgClientCert.crt

'
if [ $# -eq 5 ]; then

# Installing the Postgres Client
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
    echo -e "This script requires 5 arguments in this order : \n Example \n ./cbpostgres.sh myPGServer.com 5432 cbadmin cbP@ssw0rd http://certrepo/pgClientCert.crt
"
    exit 1;
fi
