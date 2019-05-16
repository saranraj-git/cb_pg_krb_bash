export env variables

export rgname="testclusterhdp"
export clusname="testclusterhdp"
export t3cred="t3ddepcredentials"
export bpname="hdfs-hbase-yarn-grafana-logsearch"
export ambaripwd="some-amb-pwd"
export krbpwd="somepass123"
export krbspn="ambari/admin@EXAMPLE.COM"
export kdcip="10.50.0.69"
export kadminip="10.50.0.69"
export realm="EXAMPLE.COM"
export hdprepourl="http://public-repo-1.hortonworks.com/HDP/centos7/3.x/updates/3.1.0.0"
export hdputilurl="http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.22/repos/centos7"
export vdfurl="http://public-repo-1.hortonworks.com/HDP/centos7/3.x/updates/3.1.0.0/HDP-3.1.0.0-78.xml"
export ambarirepourl="http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.7.3.0"
export extambdb="myambaridb"
export exthivedb="myhivedb"
export extrangerdb="myrangerdb"
export imgcatalog="mycustomcatalog"
export imguuid="c08fb21d-3fa6-46c1-4b41-7a4c2dd40b88"
export subnet="xaea3sub2703191930"
export nwrgname="xaea3RG2703191929"
export vnet="xaea3vnet2703191930"
export pubkey="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEA44aHHKFLmNZwrMha2ASr59QQvwA5WtsUpBFjE4mrnInw78t5chevrDuqvwx8zbrFvaCRRbat+V5waUWoj7VbrDfzpQEar4Ny9yV7+Tu9X/S144eUUtP2Svb/GJBD68MLFoHFgGrCQuyTFQP73qWD1+AY7naGmxyh/kqHt+odyFNCPrNmQJ+YnP78UTty/jLBLN//UDXChmOEYWNnMjvbyi+BVzsuHFr5zVOowXh7dHyfLWZa5E211ybH86EM0bhLr0BSDrBE3PMjVoTqxplCpIyVTQMBThpy7YQyTs+MtZjtypLJerqUmawaJ1yySMR11gMqrAKh2lp+FtlD+teuiQ== rsa-key-20190417"


Run j2 command
j2 /path/of/cb-template.j2 -o final-cb.json


Unset the Env variables

unset	rgname
unset	clusname
unset	t3cred
unset	bpname
unset	ambaripwd
unset	krbpwd
unset	krbspn
unset	kdcip
unset	kadminip
unset	realm
unset	hdprepourl
unset	hdputilurl
unset	vdfurl
unset	ambarirepourl
unset	extambdb
unset	exthivedb
unset	extrangerdb
unset	imgcatalog
unset	imguuid
unset	subnet
unset	nwrgname
unset	vnet

unset	pubkey
