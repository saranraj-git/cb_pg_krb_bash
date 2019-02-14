#!/usr/bin/env bash
: '
This script helps in integrating the Azure App Key to Cloudbreak
To execute this script, it requires 7 arguments in this order : 
	1. Cloudbreak Controller URL (eg. https://cloudbreakVM.com:443)
	2. Cloudbreak username
	3. Cloudbreak password
	4. Azure Subscription ID
	5. Azure Tenant ID (Azure AD -> Properties -> Directory ID)
	6. Azure App ID (Azure AD -> App registrations -> MyApplication -> Application ID)
  7. Azure App Password (Azure AD -> App registrations -> MyApplication -> Keys)
  
  eg: sh ./IntegrateAppKey.sh https://cloudbreakVM.com:443 root@example.com myP@ssw0rd xsubs-id-detailx xtent-idx xapp-id-x xapp-pwdx"
'
if [ $# -eq 7 ]; then

curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_2.9.0_Linux_x86_64.tgz | sudo tar -xz -C /bin cb && chmod +x /bin/cb
cb configure --server "$1" --username "$2" --password "$3"
cb credential create azure app-based --name azcred --subscription-id "$4" --tenant-id "$5" --app-id "$6" --app-password "$7"

else
    echo -e "This script requires 7 arguments in this order : \n <CB_ServerName> <CB_Username> <CB_Password> <Az_Sub-id> <Az_Ten-id> <Az-AppID> <Az-AppPwd>"
    exit 1;
fi
