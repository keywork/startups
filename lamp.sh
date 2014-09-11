#/bin/sh

####  Install Packages for https and mysql
yum -y install httpd httpd-devel 
yum -y install mysql mysql-server mysql-devel
##### Open firewall for http and SSL
iptables -F
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart
/etc/init.d/httpd start
chkconfig httpd on

#### Start mysql and set root password
/etc/init.d/mysqld start
chkconfig mysqld on
mysql <<EOF
USE mysql;
UPDATE user SET Password=PASSWORD('CHANGEMEPLEASE') WHERE user='root';
FLUSH PRIVILEGES;
EOF

##Install PHP
yum -y install php php-common php-mysql php-gd php-mbstring php-mcrypt php-xml php-devel

/etc/init.d/httpd restart
touch /var/www/html/index.php
echo "<?php phpinfo();?>" >> /var/www/html/index.php
