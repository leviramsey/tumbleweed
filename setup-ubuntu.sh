#!/bin/bash
#	Easy setup for an Ubuntu machine
#
#	(C) Levi Ramsey for Tumbleweed, MIT License
#
#	NB: I am not normally an Ubuntu/Debian user
#	
#	When installing mysql, the installer will ask you for a password for the
#	 'root' database user.  This password DOES NOT AND PROBABLY SHOULD NOT
#	 BE the same as your Unix root password!  However, remember the password
#	 you enter!

sudo add-apt-repository ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install software-properties-common python-software-properties nodejs make mysql-server curl mongodb

sudo npm install

for i in `cat perl_packages`; do
	perl -MCPAN -e "install $i"
done

mysql -u root -p < tier2/schema.sql
