#/bin/sh

install_dir="/var/www/html"
#Creating Random WP Database Credenitals
db_name="wp`date +%s`"
db_user=$db_name
db_password=`date |md5sum |cut -c '1-12'`
sleep 1
mysqlrootpass=`date |md5sum |cut -c '1-12'`
sleep 1
ftp_password=`date |md5sum |cut -c '1-12'`


####  Install Packages for https and mysql
yum -y install httpd httpd-devel 
yum -y install mysql mysql-server mysql-devel
yum -y install lynx vsftpd
##### Open firewall for http and SSL
iptables -F
iptables -A INPUT -i lo -j ACCEPT
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

sed -i  '0,/AllowOverride\ None/! {0,/AllowOverride\ None/ s/AllowOverride\ None/AllowOverride\ All/}' /etc/httpd/conf/httpd.conf

/etc/init.d/httpd restart

#Download and extract latest Wordpress Package
if test -f /tmp/latest.tar.gz
then
    echo "WP is already downloaded."
else
    echo "Downloading Wordpress"
    cd /tmp/ && wget "http://wordpress.org/latest.tar.gz"
fi

/bin/tar -C $install_dir -zxf /tmp/latest.tar.gz --strip-components=1
chown apache: $install_dir -R
echo $ftp_password | passwd apache --stdin
/etc/init.d/vsftpd start
chkconfig vsftpd on
/etc/init.d/vsftpd restart

#### Create WP-config and set DB credentials
/bin/mv $install_dir/wp-config-sample.php $install_dir/wp-config.php

/bin/sed -i "s/database_name_here/$db_name/g" $install_dir/wp-config.php
/bin/sed -i "s/username_here/$db_user/g" $install_dir/wp-config.php
/bin/sed -i "s/password_here/$db_password/g" $install_dir/wp-config.php

cat << EOF >> $install_dir/wp-config.php
define('FS_METHOD', 'ftpext');
define('FTP_BASE', '$install_dir');
define('FTP_USER', 'apache');
define('FTP_PASS', '$ftp_password');
define('FTP_HOST', '127.0.0.1');
define('FTP_SSL', false);
EOF

cat << EOF >> $install_dir/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

chown apache: $install_dir -R

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
echo "FTP Password: " $ftp_password
