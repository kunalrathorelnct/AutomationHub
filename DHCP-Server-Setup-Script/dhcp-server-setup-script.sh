#!/bin/bash

###################################################################################################
#                                                                                                 #
#Script was created by: Akash Semil																  #
#																								  #
###################################################################################################

# Add Firewall rule
function manage_firewall
{
	if firewall-cmd --permanent --add-service=dhcp &&
		firewall-cmd --reload
	then
		echo "Status: dhcp firewall rule added"
		echo "Finish: Script Completed Successfully"
	else
		echo "Error: Script Failed: Failed to add firewall rule"
	fi
}

# Manage Service
function manage_services
{
	if systemctl restart dhcpd &&
		systemctl enable dhcpd
	then
		echo "Status: dhcpd service started and enabled"
		manage_firewall
	else
		echo "Error: Failed to start dhcpd service: Check /etc/dhcp/dhcpd.conf"
	fi
}

# Configuration dhcpd.conf
function configuration
{
	echo "# dhcpd.conf
subnet $subnet netmask $subnetmask {
	range $spool $epool;
	option routers $router;
	option broadcast-address $broadcast;
	default-lease-time 600;
	max-lease-time 7200;
}" > /etc/dhcp/dhcpd.conf
	manage_services
}

# Package Installation
function package_installation
{
	if yum install dhcp -y
	then
		echo "Status: Package Installation Successfull"
		configuration
	else
		echo "Error: Script Failed : Package Installation Failed"
	fi
}

# Pre-Check
if [ $(whoami) == "root" ]
then
	if grep rhel /etc/os-release ||
		grep centos /etc/os-release
	then
		echo -e "Status: This script will setup a ipv4 dhcp server\nAny previous installation and configuration will be removed."
		read -p "Do you want to continue (y/n): " choice
		if [ $choice == 'y' ]
		then
		ip a
		read -p "Enter Subnet/Network Address(eg. 192.168.4.0): " subnet
		read -p "Enter Subnet Mask Address(eg. 255.255.255.0): " subnetmask
		read -p "Enter DHCP Start Pool Address(eg. 192.168.4.100): " spool
		read -p "Enter DHCP End Pool Address(eg. 192.168.4.200): " epool
		read -p "Enter Router Address(eg. 192.168.4.254): " router
		read -p "Enter Broadcast Address(eg. 192.168.4.255): " broadcast
			if rpm -q dhcp
			then
				echo "Warning: previous installation found"
				if yum erase dhcp -y
				then
					echo "Warning: previous installation removed"
					if [ -f /etc/dhcp/dhcp.conf.rpmsave ]
					then
						rm -rf /etc/dhcp/dhcp.conf.rpmsave
					fi
				fi
			fi
			package_installation
		else
			exit
		fi
	else
		echo "Error: This script is only for centos and rhel family"
	fi
else
	echo "Error: run script as root"
fi
