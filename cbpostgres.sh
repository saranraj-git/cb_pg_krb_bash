#!/usr/bin/env bash
pgserver="" #eg: cbreakpsql.postgres.database.azure.com
pgserverport=""  # 5432
pgserverusername="" #psqladmin@postgresserver
pgserverpassword="" # MyserverP@ssword


cat >> /var/lib/cloudbreak-deployment/Profile << END
export DATABASE_HOST=$pgserver
export DATABASE_PORT=5432
export DATABASE_USERNAME=psqladmin@cbreakpsql
export DATABASE_PASSWORD=Hadoop-123
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
