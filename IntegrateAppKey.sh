#!/usr/bin/env bash
: '
This script helps in integrating the Azure App Key to Cloudbreak
Ingredients required for running this script would be:
1. Azure Subscription ID
2. Tenant ID (Azure AD -> Properties -> Directory ID)
3. Application ID (Azure AD -> App registrations -> MyApplication -> Application ID)
4. Application Password (Azure AD -> App registrations -> MyApplication -> Keys )
'
subs=" "
tentid=" "
appid=" "
apppwd=" "

cb credential list --table

cb credential create azure app-based --name MyAzureCred --subscription-id $subs --tenant-id $tentid --app-id $appid --app-password $apppwd
