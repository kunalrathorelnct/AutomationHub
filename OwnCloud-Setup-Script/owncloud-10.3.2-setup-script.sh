#!/bin/bash
###################################################################################################
#                                                                                                 #
# Script was created by: Akash Semil															  #
# github.com/akashsemil																			  #
#																								  #
###################################################################################################
# Default Passwords																				  #
#																								  #
# Mariadb root user Password: owncloud                                                            #
# Mariadb owncloud user Password: owncloud														  #
# Owncloud Portal admin Password: password														  #
#																								  #
##################################################################################################
function setting_mariadb
{
	#Installing Mariadb Server
	if yum install mariadb-server -y &> script.out
	then
		echo "Status: Mariadb Server Installed"
		if systemctl enable mariadb --now &> script.out
		then
			echo "Status: Mariadb Server Started & Enabled"
			#mysql_secure_installation
			(echo "
y
owncloud
owncloud
" | mysql_secure_installation --stdin) &> script.out
			#Creating Database and user
			mysql -uroot -powncloud <<EOF
CREATE DATABASE owncloud;
CREATE USER 'owncloud'@'localhost' IDENTIFIED BY 'owncloud';
GRANT ALL PRIVILEGES ON owncloud.* to 'owncloud'@'localhost';
EOF
			if systemctl restart mariadb.service &> script.out
			then
				echo "Status: mariadb-server configuration completed"
			else
				echo "Error: while configuring mariadb"
			fi
		else
			echo "Error: while starting & enabling Mariadb Server"
		fi
	else
		echo "Error: while installing Mariadb Server"
		exit
	fi
}
function setting_php_repo
{
	#Adding EPEL Repo
	if yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y &> script.out
	then
		echo "Status: Installing epel release"
		#Adding Remi Repo
		if yum install https://rpms.remirepo.net/enterprise/remi-release-7.rpm -y &> script.out
		then
			echo "Status: Installing remi release"
			#Installing yum-utils
			if yum install yum-utils -y &> script.out
			then
				echo "Status: Installing yum-utils"
				#Enabling php72
				if yum-config-manager --enable remi-php72 -y &> script.out
				then
					echo "Status: enabling remi-php72"
				else
					echo "Error: While enabling remi-php72"
				fi
			else
				echo "Error: while installing yum-utils"
				exit
			fi
		else
			echo "Error: while downloading remi-release-7.rpm"
			exit
		fi
	else
		echo "Error: while downloading epel-release-latest-7.rpm"
		exit
	fi
}
function setting_webserver
{
	setting_php_repo
	setting_mariadb
	if yum install httpd php72 mod_php php-posix php-mysqlnd php-mbstring php-intl php-zip php-dom php-gd -y &> script.out
	then
		echo "Status: httpd & php7.2 Installed"
		if [ -f /tmp/owncloud-10.3.2.tar.bz2 ]
		then
			tar -xf /tmp/owncloud-10.3.2.tar.bz2 -C /var/www/html
			chown apache:apache -R /var/www/html/owncloud
			chmod 750 -R /var/www/html/owncloud
			# Requisite
			read -p "Enter this Machine IP Address: " ipaddress
			semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/owncloud/data(/.*)?'
			semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/owncloud/config(/.*)?'
			semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/owncloud/apps(/.*)?'
			semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/owncloud/apps-external(/.*)?'
			semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/owncloud/.htaccess'
			semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/owncloud/.user.ini'
			semanage fcontext -a -t httpd_sys_rw_content_t '/var/www/html/owncloud/data(/.*)?'
			restorecon -RF /var/www/html/owncloud
			sudo -u apache php /var/www/html/owncloud/occ maintenance:install --database "mysql" --database-name "owncloud" --database-user "owncloud" --database-pass "owncloud" --admin-user "admin" --admin-pass "password"
			sed -i '7 a\
    1 => '\'$ipaddress\'',' /var/www/html/owncloud/config/config.php
		fi
	else
		echo "Error: While installing Apache WebServer"
		exit
	fi
	if systemctl enable httpd --now &> script.out
	then
		echo "Status: httpd Service Running & Enabled"
		restorecon -RF /var/www/html/owncloud
	else
		echo "Error: Failed to start & enable httpd service"
	fi
	if firewall-cmd --permanent --add-service=http &> script.out &&
		firewall-cmd --reload &> script.out
	then
		echo "Status: Firewall: http Allowed"
	else
		echo "Error: Failed to add firewall rule"
	fi
	echo "Status: OwnCloud Setup Completed"
	echo "Status: Open url http://"$ipaddress"/owncloud"
	echo -e "Passwords:\nMariadb root password: owncloud\nMariadb owncloud user password: owncloud\nOwncloud Portal admin user password: password"
}
function download_owncloud
{
	if yum install wget bzip2 -y &> script.out
	then
		echo "Status: wget & bzip2 installed"
		if wget -P /tmp https://download.owncloud.org/community/owncloud-10.3.2.tar.bz2 &> script.out
		then
			echo "Status: OwnCloud Files Downloaded"
			setting_webserver
		else
			echo "Error: Unable to Download OwnCloud files"
			exit
		fi
	fi
}
#Pre-Checks
if [ $(whoami) == "root" ] 
then
	if grep rhel /etc/os-release &> /dev/null
	then
		echo "Status: Starting OwnCloud Server Setup"
		echo "This script requires internet connection to setup owncloud server"
		download_owncloud
	else
		echo "This Script is for RHEL FAMILY OS ONLY."
	fi
else
	echo "Error: Run script as root."
	exit 1
fi
