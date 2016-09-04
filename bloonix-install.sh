#!/bin/bash

# Version 1.0
# This small script automates the installation
# of the bloonix monitoring-suite
# more information: https://github.com/dominicpratt/bloonix-install
# Author: Dominic Pratt (https://dominicpratt.de)

# Simple check if this is a debian based distribution
if [ -f /etc/debian_version ]; then
  echo -e "Starting Bloonix-Installation..."
  echo -e "Please be patient."
else
  echo -e "This is not a debian based distribution!"
  echo -e "Please use this script only on debian based distributions."
  echo -e "Aborting..."
  exit 1
fi

install_dependencies() {
  apt-get -qq remove apt-listchanges
  apt-get -qq update
  apt-get -qq install apt-transport-https ca-certificates pwgen curl openjdk-7-jre
}

bloonix_repository() {
  # Adding Bloonix-Repository
  wget -q -O- https://download.bloonix.de/repos/debian/bloonix.gpg | apt-key add -
  echo "deb https://download.bloonix.de/repos/debian/ jessie main" >> /etc/apt/sources.list.d/bloonix.list
  apt-get -qq update
}

elasticsearch_repository() {
  # Adding elasticsearch-Repository
  wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" >> /etc/apt/sources.list.d/elasticsearch.list
  apt-get -qq update
  apt-get -qq install elasticsearch
}

install_mysql_server() {
  # Installating MySQL-Server from debian-repositories and setting root password
  MYSQL_PASSWORD=`pwgen 12`
  echo mysql-server mysql-server/root_password password $MYSQL_PASSWORD | debconf-set-selections
  echo mysql-server mysql-server/root_password_again password $MYSQL_PASSWORD | debconf-set-selections
  apt-get -qq install mysql-server
  echo $MYSQL_PASSWORD > /root/MYSQL_PASSWORD.txt
}

install_nginx() {
  apt-get -qq install nginx
  sed -i 's/.*server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/' /etc/nginx/nginx.conf
}

initialize_mysql_database() {
  # Initialize MySQL-Database schema
  echo -e ""
  echo -e "!!! IMPORTANT !!!"
  echo -e "This is the password for mysql-root: $MYSQL_PASSWORD"
  echo -e "Please copy and paste it to the next step!"
  /srv/bloonix/webgui/schema/init-database --mysql
}

initialize_elasticsearch() {
  # Initialize Elasticsearch-Schema
  service elasticsearch start
  sleep 10
  sed -i 's/.*network.host:.*/network.host: 127.0.0.1/' /etc/elasticsearch/elasticsearch.yml
  /srv/bloonix/webgui/schema/init-elasticsearch localhost:9200
}

install_bloonix_webgui() {
  apt-get -qq install bloonix-webgui
  echo "include /etc/bloonix/webgui/nginx.conf;" > /etc/nginx/conf.d/bloonix.conf
  service nginx restart
  service bloonix-webgui restart
}

install_bloonix_server() {
  apt-get -qq install bloonix-server
  service bloonix-server restart
}

install_bloonix_plugins() {
  apt-get -qq install bloonix-plugins-* bloonix-plugin-config
  bloonix-load-plugins --load-all
}

install_bloonix_agent() {
  apt-get -qq install bloonix-agent
}

install_dependencies
bloonix_repository
elasticsearch_repository
install_mysql_server
install_nginx
install_bloonix_webgui
initialize_mysql_database
initialize_elasticsearch
install_bloonix_server
install_bloonix_plugins
install_bloonix_agent

service bloonix-webgui restart

echo -e "Your bloonix-instance should be up and running."
echo -e "Please check with your browser."
echo -e "Initial Login for Bloonix is: admin/admin"
echo -e "For further documentation on Bloonix please look at https://bloonix.org/de/docs/about/about.html"
echo -e "Happy monitoring!"
