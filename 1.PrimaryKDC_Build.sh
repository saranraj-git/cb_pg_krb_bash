#!/bin/env bash
echo "Deploying the packages"
yum -y install krb5-server krb5-libs krb5-workstation httpd

echo "Updating KRB5.config file"
#export DOMAIN=$(hostname -d)
export REALMUPPER="TESTDDEP.COM"
# $(echo ${DOMAIN} | awk '{print toupper($0)}')
export REALMLOWER="testddep.com"
# $(echo ${DOMAIN} | awk '{print tolower($0)}')
cp /etc/krb5.conf /etc/krb5.confbkp
sed -i "s/kerberos.example.com/$(hostname -f)/g" /etc/krb5.conf
sed -i "s/example.com/$REALMLOWER/g" /etc/krb5.conf
sed -i "s/EXAMPLE.COM/$REALMUPPER/g" /etc/krb5.conf
sed -i "s/# //g" /etc/krb5.conf

echo "Updating kadm5.acl file"
cp /var/kerberos/krb5kdc/kadm5.acl /var/kerberos/krb5kdc/kadm5.aclbkp
sed -i "s/EXAMPLE.COM/$REALMUPPER/g" /var/kerberos/krb5kdc/kadm5.acl

echo "Creating KDC database"
echo "Hadoop-123" > kdbutilpwd.txt
echo "Hadoop-123" >> kdbutilpwd.txt
kdb5_util create -s < kdbutilpwd.txt

echo "Starting krb5kdc & kadmin"
systemctl start krb5kdc
systemctl start kadmin
systemctl enable krb5kdc 
systemctl enable kadmin

echo "Creating root and admin principals"
kadmin.local -q "addprinc admin/admin" < kdbutilpwd.txt
kadmin.local -q "addprinc root/admin" < kdbutilpwd.txt

echo "Restarting the kadmin"
systemctl restart kadmin

echo "List of user principals as follows"
kadmin.local -q "listprincs"

#==== Run the following on the master KDC========="

PrimaryKDC="srjkdc-1.field.hortonworks.com"
SecondaryKDC="srjkdc-2.field.hortonworks.com"
KDCrealmname="TESTDDEP.COM"

echo "Create new service principals for the primary and secondary KDC host"
kadmin.local -q "addprinc -randkey host/$PrimaryKDC" 
kadmin.local -q "addprinc -randkey host/$SecondaryKDC" 

echo "Generate a random key for the master KDC & secondary KDC "
kadmin.local -q "ktadd host/$PrimaryKDC" 
kadmin.local -q "ktadd -k /tmp/$SecondaryKDC.keytab host/$SecondaryKDC"

echo "Copying the files from Primary to secondary"
cp /var/kerberos/krb5kdc/kdc.conf /tmp/
cp /etc/krb5.conf /tmp/
cp /var/kerberos/krb5kdc/.k5.* /tmp/
cp /var/kerberos/krb5kdc/kadm5.acl /tmp/

pushd /tmp/
tar -czf kdc1.tar.gz $SecondaryKDC.keytab kdc.conf krb5.conf kadm5.acl .k5.*
cp kdc1.tar.gz /var/www/html/
systemctl restart httpd && systemctl enable httpd

