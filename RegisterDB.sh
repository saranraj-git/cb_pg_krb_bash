#!/bin/bash
: '
This script helps in integrating the Postgres databases (for HDP/HDF clusters) to Cloudbreak:
It requires the following as input:
1. Postgres DB server FQDN
2. DB Username and password
3. Cloudbreak deployer VM fqdn along with the username and password for Cloudbreak WebUI
'
# Getting the inputs as parameter for Cloudbreak WebUI and postgres server 
pgserver="cbpostgres.postgres.database.azure.com"
pgusername="cbpsqladmin@cbpostgres"
pgpwd="Hadoop-12345"
cburl="https://cbvm.com"
cbuser="cbadmin@example.com "
cbpasswd="Hadoop-123"

# Installing and configuring CB utility 
curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /bin cb && chmod +x /bin/cb
cb configure --server $cburl --username $cbuser --password $cbpasswd

# Integrate Postgres DB created for HDP/HDF clusters with Cloudbreak
cb database create postgres --name ambaridb --type AMBARI --url jdbc:postgresql://$pgserver:5432/ambari?ssl=true  --db-username $pgusername --db-password $pgpwd
cb database create postgres --name hivedb --type HIVE --url jdbc:postgresql://$pgserver:5432/hive?ssl=true --db-username $pgusername --db-password $pgpwd
cb database create postgres --name rangerdb --type RANGERDB --url jdbc:postgresql://$pgserver:5432/rangerdb?ssl=true --db-username $pgusername --db-password $pgpwd
cb database create postgres --name nifiregdb --type REGISTRY --url jdbc:postgresql://10.50.0.164:5432/registry  --db-username registryadmin --db-password Hadoop123

# Validate the databases avail
cb database list --output table

# Output would be the looks like the following
:' Table output 
+------------+---------------------------------------------+----------------+----------+-----------------------+
|    NAME    |                CONNECTIONURL                | DATABASEENGINE |   TYPE   |        DRIVER         |
+------------+---------------------------------------------+----------------+----------+-----------------------+
| myhivedb   | jdbc:postgresql://10.50.0.164:5432/hive     | POSTGRES       | HIVE     | org.postgresql.Driver |
| myrangerdb | jdbc:postgresql://10.50.0.164:5432/ranger   | POSTGRES       | RANGER   | org.postgresql.Driver |
| nifiregdb  | jdbc:postgresql://10.50.0.164:5432/registry | POSTGRES       | REGISTRY | org.postgresql.Driver |
| myambaridb | jdbc:postgresql://10.50.0.164:5432/ambari   | POSTGRES       | AMBARI   | org.postgresql.Driver |
+------------+---------------------------------------------+----------------+----------+-----------------------+

JSON output

[
  {
    "Name": "myambaridb",
    "ConnectionURL": "jdbc:postgresql://10.50.0.164:5432/ambari",
    "DatabaseEngine": "POSTGRES",
    "Type": "AMBARI",
    "Driver": "org.postgresql.Driver"
  },
  {
    "Name": "myrangerdb",
    "ConnectionURL": "jdbc:postgresql://10.50.0.164:5432/ranger",
    "DatabaseEngine": "POSTGRES",
    "Type": "RANGER",
    "Driver": "org.postgresql.Driver"
  },
  {
    "Name": "myhivedb",
    "ConnectionURL": "jdbc:postgresql://10.50.0.164:5432/hive",
    "DatabaseEngine": "POSTGRES",
    "Type": "HIVE",
    "Driver": "org.postgresql.Driver"
  },
  {
    "Name": "nifiregdb",
    "ConnectionURL": "jdbc:postgresql://10.50.0.164:5432/registry",
    "DatabaseEngine": "POSTGRES",
    "Type": "REGISTRY",
    "Driver": "org.postgresql.Driver"
  }
]


'
