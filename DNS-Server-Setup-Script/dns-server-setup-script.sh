#!/bin/bash
###################################################################################################
#                                                                                                 #
#Script was created by: Akash Semil																  #
#																								  #
###################################################################################################

#Pre Requisite
clear
read -p "Enter the Domain Name (eg. example.com) : " domain_name
read -p "Enter the IP Address (eg. 192.168.0.254) : " ip_address
read -p "Enter the Machine FQDN (eg server.example.com) : " fqdn
read -p "Enter the Gateway IP Address (eg. 192.168.1.1) : " gateway
rev_ip=$(echo $ip_address | cut -d '.' -f3).$(echo $ip_address | cut -d '.' -f2).$(echo $ip_address | cut -d '.' -f1)
hostname=$(echo $fqdn | cut -d '.' -f1)

#CleanUp While Error
function cleanup
{
	echo "Error: Error encountered while running the script"
	echo "Status: Rolling Back Changes"
	if yum remove bind -y &> /dev/null
	then
		echo "" > /etc/resolv.conf
		echo "Status: CleanUp completed successfully"
		echo "Failed: Unable to Setup DNS Server"
	else
		echo "Error: CleanUp Failed"
	fi
}

#Finishing Up
function post
{
	if hostnamectl set-hostname $fqdn
	then
		echo -e "search $domain_name\nnameserver $ip_address" > /etc/resolv.conf
		echo "Status: Setting up hostname and DNS"
	fi
	echo "Finish: DNS Server Up and Running"
	exit 0
}

#Starting up Service
function services
{
	
	if systemctl restart named && systemctl enable named &> /dev/null
	then
		echo "Status: Starting and Enabling Services"
		post
	else
		echo "Error: Failed to start Service"
		cleanup
	fi
	
}

#Setting Zone Files
function zonefiles
{
	if [ -d /var/named ]
	then
		echo "Status: Setting up zone files in /var/named/"
		head -7 /var/named/named.empty > /var/named/forward.zone
		sed -i 's/@ rname.invalid/root.'$domain_name'. '$fqdn'/' /var/named/forward.zone
		cp /var/named/forward.zone /var/named/reverse.zone
		echo -e "\t\tNS\t@" >> /var/named/forward.zone
		echo -e "\t\tA\t$ip_address" >> /var/named/forward.zone
		echo -e "$hostname\tIN\tA\t$ip_address" >> /var/named/forward.zone
		echo -e "\t\tNS\t@" >> /var/named/reverse.zone
		echo -e "\t\tA\t$ip_address" >> /var/named/reverse.zone
		echo -e $(echo $ip_address | cut -d '.' -f4)"\tIN\tPTR\t$fqdn." >> /var/named/reverse.zone
		chgrp named /var/named/forward.zone
		chgrp named /var/named/reverse.zone
		services
	else
		echo "Error: /var/named directory not found."
		cleanup
	fi
}

#Configurations for /etc/named.conf
function configuration
{
	if [ -f /etc/named.conf ]
	then
		echo "Status: Configuring DNS Server"
		sed -i 's/127.0.0.1/'"$ip_address"'/' /etc/named.conf
		sed -i 's/localhost/any/g' /etc/named.conf
		echo -e "zone \"$domain_name\" IN { \n\t type master;\n\t file \"/var/named/forward.zone\";\n};" >> /etc/named.conf
		echo -e "zone \"$rev_ip.in-addr.arpa\" IN { \n\t type master;\n\t file \"/var/named/reverse.zone\";\n};" >> /etc/named.conf
		sed -i '20iforwarders	 { '$gateway'; };' /etc/named.conf
		zonefiles
	else
		echo "Error: Configuration File Not Found"
		cleanup
	fi
}

#Package Installation
function installation
{
	echo "Status: Installing Bind Package"
	if yum install bind -y &> /dev/null
	then
		echo "Status: Installation Successfull"
		configuration
	else
		echo "Error: Installation Failed"
		cleanup
	fi
}

#Pre-Checks
if [ $(whoami) == "root" ] 
then
	if grep rhel /etc/os-release &> /dev/null
	then
		echo "Status: Starting DNS Server Setup"
		if [ $(rpm -qa bind) ]
		then
			if yum remove bind -y &> script.out
			then
				echo "Warning: Removing Package from previous installation"
				echo "" > /etc/resolv.conf
			else
				echo "Error: Unable to remove package"
				exit 1
			fi
			if [ -f /etc/named.conf.rpmsave ]
			then
				echo "Warning: Previous Configuration Found, Removing"
				rm -rf /etc/named.conf.rpmsave
			fi
		fi
	else
		echo "This Script will not be able to run as it is designed for RHEL Family OS."
		exit 2
	fi
	installation
else
	echo "Error: Run script as root."
	exit 1
fi
