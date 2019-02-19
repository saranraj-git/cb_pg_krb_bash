This Repository meant for Cloudbreak components related Automation:

0.Install_PSQL_server
• Install Postgres Server
• Configure Postgres for remote login
• creates the necessary DB and users for Cloudbreak


0.Setup_SSL_Postgres
• Install OpenSSL package
• Generate CA certificate
• Generate Postgres server certificate to the required directories
• Copies the server cert to the required 
• Update the config files of Postgres server for SSL enable
• Generate Client certificate
• Install Apache Web server
• Copies the Client certificate to the Web server directory

1.cbdeployer.sh
• Installing the pre-requisites of Cloudbreak
• Download required containers and Install Cloudbreak 
• Configure Cloudbreak
• Start the Cloudbreak Web UI
• Enabling Cloudbreak to start during boot time


2.cbpostgres.sh
• Installs Postgres Client
• Placing the Postgres Client cert on the right folder
• Updates the Profile file of Cloudbreak
• Restarts the CBD docker daemons to integrate External Postgres


3.IntegrateAppKey.sh
• Download and install the CB client
• Configure the CB client
• Create the Cloudbreak credential by adding the Azure App Key

 
 
