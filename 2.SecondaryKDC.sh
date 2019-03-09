#==== Run the following on the secondary KDC========="

PrimaryKDC="srjkdc-1.field.hortonworks.com"
SecondaryKDC="srjkdc-2.field.hortonworks.com"
KDCrealmname="TESTDDEP.COM"

echo "===== Installing packages ======="
yum install krb5-server xinetd -y 
echo "host/$PrimaryKDC@$KDCrealmname" > /var/kerberos/krb5kdc/kpropd.acl 

echo "===== "
cat >> /etc/xinetd.d/kpropd-stream << END
service kpropd
{
        disable         = no
        socket_type     = stream
        protocol        = tcp
        user            = root
        wait            = no
        server          = /sbin/kpropd
}
END
echo "kpropd             754/tcp            # Kerberos Propagation Daemon" >> /etc/services
systemctl enable xinetd
systemctl start xinetd

pkdc="http://$PrimaryKDC/kdc1.tar.gz"
wget $pkdc -O /tmp/kdc1.tar.gz
pushd /tmp/
tar -xzf kdc1.tar.gz 

rm -f /var/kerberos/krb5kdc/kadm5.acl
cp /tmp/kadm5.acl /var/kerberos/krb5kdc/

rm -f /var/kerberos/krb5kdc/kdc.conf
cp /tmp/kdc.conf /var/kerberos/krb5kdc/

rm -f /etc/krb5.conf
cp /tmp/krb5.conf /etc/

rm -f /etc/krb5.keytab
cp /tmp/*.keytab /etc/
mv /etc/*.keytab /etc/krb5.keytab

rm /var/kerberos/krb5kdc/.k5.*
cp /tmp/.k5.* /var/kerberos/krb5kdc/
