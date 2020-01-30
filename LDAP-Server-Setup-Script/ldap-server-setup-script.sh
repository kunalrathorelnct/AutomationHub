#!/bin/bash
###################################################################################################
#                                                                                                 #
#Script was created by: Akash Semil																  #
#																								  #
###################################################################################################

#Pre Requirement
read -p "Enter the domain name(eg. example.com): " domain

#Create Test User
function finish
{
	echo "
Status: Script Completed Successfully, LDAP Server Setup Completed
Note: Try LDAP Test User & Use the Cert present in the working directory
username: ldaptest
password: ldaptest
SSH with the following user to Test"
	rm -rf base.ldif local-group local-user ldap-user.ldif ldap-group.ldif slappasswd
	cp /etc/pki/tls/certs/$domain.pem ./.
exit 0
}

#Create Test User
function add_test_user
{
	if useradd ldaptest 
	then
	{
		echo "ldaptest" | passwd ldaptest --stdin
		grep ldaptest /etc/passwd > local-user
		grep ldaptest /etc/group > local-group
		/usr/share/migrationtools/migrate_passwd.pl local-user > ldap-user.ldif
		/usr/share/migrationtools/migrate_group.pl local-group > ldap-group.ldif
		if ldapadd -x -W -D cn=Manager,dc=$(echo $domain | cut -d '.' -f1),dc=$(echo $domain | cut -d '.' -f2) -f ldap-user.ldif &&
			ldapadd -x -W -D cn=Manager,dc=$(echo $domain | cut -d '.' -f1),dc=$(echo $domain | cut -d '.' -f2) -f ldap-group.ldif
		then
			echo "Status: LDAP Test user is created"
			finish
		else
			echo "Error: Script Failed : While Creating Ldap User"
		fi
	}
	fi
}

#Base schema
function add_base_schema
{
	echo -e "dn: dc="$(echo $domain | cut -d '.' -f1)",dc="$(echo $domain | cut -d '.' -f2)"
dc: "$(echo $domain | cut -d '.' -f1)"
objectClass: top
objectClass: domain\n
dn: cn=Manager,dc="$(echo $domain | cut -d '.' -f1)",dc="$(echo $domain | cut -d '.' -f2)"
objectClass: organizationalRole
cn: Manager
description: LDAP Manager\n
dn: ou=People,dc="$(echo $domain | cut -d '.' -f1)",dc="$(echo $domain | cut -d '.' -f2)"
objectClass: organizationalUnit
ou: People\n
dn: ou=Group,dc="$(echo $domain | cut -d '.' -f1)",dc="$(echo $domain | cut -d '.' -f2)"
objectClass: organizationalUnit
ou: Group" > base.ldif
	echo "Status: Adding Base Schema"
	if ldapadd -x -W -D "cn=Manager,dc="$(echo $domain | cut -d '.' -f1)",dc="$(echo $domain | cut -d '.' -f2)"" -f base.ldif
	then
		echo "Status: Base Schema Added"
		add_test_user
	else
		echo "Error: Script Failed : While Adding Base Schema"
	fi
}

#Add Schema
function add_schema
{
	if ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/cosine.ldif && ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/nis.ldif && ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/inetorgperson.ldif
	then
		echo "Status: cosine,nis,inetorgperson Schema Added Successfully"
		add_base_schema
	else
		echo "Error: Script Failed : While Adding cosine,nis,inetorgperson Schema"
	fi
}

#DB_config
function db_config
{
	if cp -f /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
	then
		echo "Status: DB_CONFIG Copied"
		add_schema
	else
		echo "Error: Script Failed : While Copying DB_CONFIG"
	fi
}

#Manage Firewall
function manage_firewall
{
	echo "Status: Adding firewall rules"
	if firewall-cmd --permanent --add-service=ldap && firewall-cmd --reload
	then
		db_config
	else
		echo "Error: Script Failed : While Adding Firewall Rule"
	fi
}

#Manage Service
function manage_service
{
	if systemctl start slapd && systemctl enable slapd
	then
		echo "Status: Service started and enabled"
		manage_firewall
	else
		echo "Error: Script Failed : Unable to Start Service"
	fi
}

#Certificates
function manage_certificate
{
	function generate_certificate
	{
		echo "Status: Fill up the required information for certificate"
		if openssl req -new -x509 -nodes -out /etc/pki/tls/certs/$domain.pem -keyout /etc/pki/tls/certs/$domain.key.pem -days 365
		then
			manage_service
		else
			echo "Error: Script Failed : While Generating Certificate"
		fi
	}
	function existing_certificate
	{
		while true
		do
		{
		echo -e "Status: Kindly add pem format certificate and key file to directory /etc/pki/tls/certs: \n Certificate file name should be : 'yourdomain.pem' (eg. 'example.com.pem') \n Key file name should be 'yourdomain.key.pem' (eg. 'example.com.key.pem')."
		echo "Status: Press Enter to Continue.........."
		read
		if [ -f /etc/pki/tls/certs/$domain.pem ] &&
				[ -f /etc/pki/tls/certs/$domain.key.pem ]
			then
				manage_service
				break
			else
				echo "Error: Kindly add pem format certificate and key file"
		fi
		}
		done
	}
	choice=q
	while [ $choice == 'q' ]
	do
	{
		read -p "Do you want to generate certificate(y/n): " choice
		case $choice in
		'y')
		generate_certificate
		;;
		'n')
		existing_certificate
		;;
		*)
		echo "Error: Enter 'y' or 'n'"
		choice=q
		;;
		esac
	}
	done
}

#Configuration
function configuration
{
	# -------------------------------
	# Editing Migration Tools
	# -------------------------------
	sed -i s/padl.com/$domain/g "/usr/share/migrationtools/migrate_common.ph"
	sed -i s/dc=padl/dc="$(echo $domain | cut -d '.' -f1)"/g "/usr/share/migrationtools/migrate_common.ph"
	sed -i s/dc=com/dc="$(echo $domain | cut -d '.' -f2)"/g "/usr/share/migrationtools/migrate_common.ph"
	sed -i s/"$EXTENDED_SCHEMA = 0"/"$EXTENDED_SCHEMA = 1"/g "/usr/share/migrationtools/migrate_common.ph"
	# -------------------------------
	# Editing olcDatabase={2}hdb.ldif
	# -------------------------------
	sed -i s/dc=my-domain/dc="$(echo $domain | cut -d '.' -f1)"/g "/etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif"
	sed -i s/dc=com/dc="$(echo $domain | cut -d '.' -f2)"/g "/etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif"
	# ---------------------
	# Setting up slappasswd
	# ---------------------
	echo "Enter the password for LDAP Server: "
	if slappasswd > slappasswd
	then
		echo "olcRootPW: $(cat slappasswd)" >> "/etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif"
	fi
	# -----------------
	# Certificate Entry
	# -----------------
	echo "olcTLSCertificateFile: /etc/pki/tls/certs/"$domain".pem" >> "/etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif"
	echo "olcTLSCertificateKeyFile: /etc/pki/tls/certs/"$domain".key.pem" >> "/etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb.ldif"
	# -----------------------------------
	# Editing olcDatabase={1}monitor.ldif
	# -----------------------------------
	sed -i s/dc=my-domain/dc="$(echo $domain | cut -d '.' -f1)"/g "/etc/openldap/slapd.d/cn=config/olcDatabase={1}monitor.ldif"
	sed -i s/dc=com/dc="$(echo $domain | cut -d '.' -f2)"/g "/etc/openldap/slapd.d/cn=config/olcDatabase={1}monitor.ldif"
	echo -e "Status: Checking Configurations"
	if slaptest -u
	then
		echo "Status: Configurations OK"
		manage_certificate
		
	else
		echo "Error: Script Failed"
	fi
}

#Installation
function package_installation
{
	echo "Status: Package Installation Started"
	if yum install openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel migrationtools -y
	then
		echo "Status: Package Installed Successfully"
		configuration
	else
		echo "Error: Installation Failed"
	fi
}

#Pre Checks
if grep rhel /etc/os-release || grep centos /etc/os-release
then
	if [ $(whoami) == "root" ]
	then
		echo "This will help you to setup LDAP Server."
		package_installation
	else
		echo -e "\nError: Run as root"
	fi
else
	echo "Error: This Script is not for you.Only for rhel family"
fi
