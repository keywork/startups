#/bin/sh

install_dir="/var/www/html"
#Creating Random WP Database Credenitals
db_name="wp`date +%s`"
db_user=$db_name
db_password=`date |md5sum |cut -c '1-12'`
mysqlrootpass=`date |md5sum |cut -c '13-24'`


####  Install Packages for https and mysql
yum -y install httpd httpd-devel 
yum -y install mysql mysql-server mysql-devel
yum -y install unzip
##### Open firewall for http and SSL
iptables -F
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart
#### Start http
/etc/init.d/httpd start
chkconfig httpd on

#### Start mysql and set root password
/etc/init.d/mysqld start
chkconfig mysqld on

/usr/bin/mysql -e "USE mysql;"
/usr/bin/mysql -e "UPDATE user SET Password=PASSWORD($mysqlrootpass) WHERE user='root';"
/usr/bin/mysql -e "FLUSH PRIVILEGES;"
touch /root/.my.cnf
chmod 640 /root/.my.cnf
echo "[client]">/root/.my.cnf
echo "user=root">/root/.my.cnf
echo "password="$mysqlrootpass>/root/.my.cnf
##Install PHP
yum -y install php php-common php-mysql php-gd php-mbstring php-mcrypt php-xml php-devel php-imap

/etc/init.d/httpd restart
#touch /var/www/html/index.php
#echo "<?php phpinfo();?>" >> /var/www/html/index.php

wget https://www.phpbb.com/files/release/phpBB-3.0.12.zip
unzip phpBB-3.0.12.zip -d $install_dir
chown nobody: $install_dir -R
mv $install_dir/phpBB3/ $install_dir/phpbb/


/usr/bin/mysql -u root -e "CREATE DATABASE $db_name"
/usr/bin/mysql -u root -e "GRANT ALL PRIVILEGES ON $db_name.* to '"$db_user"'@'localhost' IDENTIFIED BY '"$db_password"';"

######Display generated passwords to log file.
echo "Database Name: " $db_name
echo "Database User: " $db_user
echo "Database Password: " $db_password
echo "Mysql root password(Not used in installation. Keep for your records: " $mysqlrootpass
