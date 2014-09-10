#/bin/sh

install_dir="/var/www/html"
#Creating Random WP Database Credenitals
db_name="wp`date +%s`"
db_user=$db_name
db_password=`date |md5sum |cut -c '1-12'`
mysqlrootpass=`date |md5sum |cut -c '12-24'`


####  Install Packages for https and mysql
yum -y install httpd httpd-devel 
yum -y install mysql mysql-server mysql-devel
yum -y install lynx
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
yum -y install php php-common php-mysql php-gd php-mbstring php-mcrypt php-xml php-devel

/etc/init.d/httpd restart
#touch /var/www/html/index.php
#echo "<?php phpinfo();?>" >> /var/www/html/index.php


#Download and extract latest Wordpress Package
if test -f /tmp/latest.tar.gz
then
    echo "WP is already downloaded."
else
    echo "Downloading Wordpress"
    cd /tmp/ && wget "http://wordpress.org/latest.tar.gz"
fi

/bin/tar -C $install_dir -zxf /tmp/latest.tar.gz --strip-components=1
chown nobody: $install_dir -R

#### Create WP-config and set DB credentials
/bin/mv $install_dir/wp-config-sample.php $install_dir/wp-config.php

/bin/sed -i "s/database_name_here/$db_name/g" $install_dir/wp-config.php
/bin/sed -i "s/username_here/$db_user/g" $install_dir/wp-config.php
/bin/sed -i "s/password_here/$db_password/g" $install_dir/wp-config.php

##### Set WP Salts
grep -A50 'table_prefix' $install_dir/wp-config.php > /tmp/wp-tmp-config
/bin/sed -i '/**#@/,/$p/d' $install_dir/wp-config.php
/usr/bin/lynx --dump -width 200 https://api.wordpress.org/secret-key/1.1/salt/ >> $install_dir/wp-config.php
/bin/cat /tmp/wp-tmp-config >> $install_dir/wp-config.php && rm /tmp/wp-tmp-config -f
/usr/bin/mysql -u root -e "CREATE DATABASE $db_name"
/usr/bin/mysql -u root -e "GRANT ALL PRIVILEGES ON $db_name.* to '"$db_user"'@'localhost' IDENTIFIED BY '"$db_password"';"

######Display generated passwords to log file.
echo "Database Name: " $db_name
echo "Database User: " $db_user
echo "Database Password: " $db_password
echo "Mysql root password: " $mysqlrootpass
