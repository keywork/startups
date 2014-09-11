#/bin/sh
db_name="wp`date +%s`"
db_user=$db_name
db_password=`date |md5sum |cut -c '1-12'`

ip_addr=$(ifconfig | grep -v '127.0.0.1' | sed -n 's/.*inet addr:\([0-9.]\+\)\s.*/\1/p')
##### Open firewall for http and SSL
iptables -F
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart

yum -y remove mysql* mysql-server mysql-devel mysql-libs 

rpm -ivh http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm

rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm

rpm -ivh http://yum.postgresql.org/9.3/redhat/rhel-6-i386/pgdg-centos93-9.3-1.noarch.rpm
sed -i '/\[remi\]/,/^ *\[/ s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo
sed -i '/\[remi-php56\]/,/^ *\[/ s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo

touch /etc/yum.repos.d/nginx.repo

cat <<EOF > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=0
enabled=1
EOF

yum -y update
yum -y install nginx postgresql93 postgresql93-libs postgresql93-server wget php-fpm php-gd php-ldap php-pear php-xml php-xmlrpc php-magickwand php-magpierss php-mbstring php-mcrypt php-shout php-snmp php-soap php-tidy php-pgsql php-pdo

/etc/init.d/postgresql-9.3 initdb
/etc/init.d/postgresql-9.3 start
chkconfig postgresql-9.3 on
/etc/init.d/nginx start
chkconfig nginx on
/etc/init.d/nginx stop

su - -c "psql" postgres
CREATE USER $db_user WITH PASSWORD $db_password;
CREATE DATABASE $db_name OWNER $db_user ENCODING 'UTF8';
GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;
\q

sed -i '/post_max_size/c\post_max_size = 2G' /etc/php.ini 
sed -i '/cgi.fix_pathinfo/c\cgi.fix_pathinfo = 0' /etc/php.ini
sed -i '/upload_max_filesize/c\upload_max_filesize = 2G' /etc/php.ini
sed -i '/date.timezone/c\date.timezone = "UTC"' /etc/php.ini

chkconfig php-fpm on
/etc/init.d/php-fpm start

sed '0,/ident/! {0,/ident/ s/ident/password/}' /var/lib/pgsql/9.3/data/pg_hba.conf
cd /etc/nginx
mkdir -p cert
cd conf.d
touch oc.conf
cat <<EOF >oc.conf
upstream php-handler {
	server 127.0.0.1:9000;
    #server unix:/var/run/php5-fpm.sock;
}

server {
       listen 80;
       server_name $ip_addr;
       return 301 https://$server_name$request_uri;  # enforce https
}


server {
        listen 443 ssl;
        server_name $ip_addr;

        ssl_certificate /etc/nginx/cert/server.crt;
        ssl_certificate_key /etc/nginx/cert/server.key;

        # Path to the root of your installation
        root /var/www/owncloud/;

        client_max_body_size 10G; # set max upload size
        fastcgi_buffers 64 4K;

        rewrite ^/caldav(.*)$ /remote.php/caldav$1 redirect;
        rewrite ^/carddav(.*)$ /remote.php/carddav$1 redirect;
        rewrite ^/webdav(.*)$ /remote.php/webdav$1 redirect;

        index index.php;
        error_page 403 /core/templates/403.php;
        error_page 404 /core/templates/404.php;

        location = /robots.txt {
            allow all;
            log_not_found off;
            access_log off;
        }
        location ~ ^/(data|config|\.ht|db_structure\.xml|README) {
                deny all;
        }

        location / {
                # The following 2 rules are only needed with webfinger
                rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
                rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;

                rewrite ^/.well-known/carddav /remote.php/carddav/ redirect;
                rewrite ^/.well-known/caldav /remote.php/caldav/ redirect;

                rewrite ^(/core/doc/[^\/]+/)$ $1/index.html;

                try_files $uri $uri/ index.php;
        }

        location ~ ^(.+?\.php)(/.*)?$ {
                try_files $1 = 404;

                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME $document_root$1;
                fastcgi_param PATH_INFO $2;
                fastcgi_param HTTPS on;
                fastcgi_pass php-handler;
       }

        # Optional: set long EXPIRES header on static assets
        location ~* ^.+\.(jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {
                expires 30d;
                # Optional: Do not log access to assets
                access_log off;
}

}
EOF

cd ..
cd cert
openssl req -x509 -nodes -sha384 -days 3650 -newkey rsa:4096 -keyout server.key -out server.crt -subj "/"
chmod 600 server.key
chmod 600 server.crt

cd /var/www
wget https://download.owncloud.org/community/owncloud-7.0.2.tar.bz2
tar xjf owncloud-7.0.2.tar.bz2
mkdir -p owncloud/data
chmod 770 owncloud/data
chmod 777 owncloud/config/
chown -R root:apache owncloud
rm -rf owncloud-7.0.2.tar.bz2

/etc/init.d/postgresql-9.3 restart
/etc/init.d/nginx start

######Display generated passwords to log file.
echo "Database Name: " $db_name
echo "Database User: " $db_user
echo "Database Password: " $db_password
echo "Visit your OwnCloud at https://"$ip_addr

