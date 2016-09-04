#!/bin/bash

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

function install_dependencies() {
  apt-get -qq -y update
  apt-get -qq -y install apt-transport-https ca-certificates pwgen
}

function bloonix_repository() {
  # Adding Bloonix-Repository
  wget -q -O- https://download.bloonix.de/repos/debian/bloonix.gpg | apt-key add -
  echo "deb https://download.bloonix.de/repos/debian/ jessie main" >> /etc/apt/sources.list.d/bloonix.list
  apt-get -qq -y update
}

function elasticsearch_repository() {
  # Adding elasticsearch-Repository
  wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" >> /etc/apt/sources.list.d/elasticsearch.list
  apt-get -qq -y update
}

function install_mysql-server() {
  # Installating MySQL-Server from debian-repositories and setting root password
  export DEBIAN_FRONTEND="noninteractive"
  apt-get -qq -y install  mysql-server
}

function set_mysql_root_pw() {
  MYSQL_PW=$(pwgen 12)
  mysqladmin -u root password "$MYSQL_PW"
  echo "$MYSQL_PW" > /root/MYSQL_PASSWORD.txt
}

function install_nginx() {
  apt-get install -y nginx
  sed -i 's/.*server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/' /etc/nginx/nginx.conf
}

function initialize_mysql_database() {
  # Initialize MySQL-Database schema
  /srv/bloonix/webgui/schema/init-database --mysql
}

function initialize_elasticsearch() {
  # Initialize Elasticsearch-Schema
  /srv/bloonix/webgui/schema/init-elasticsearch localhost:9200
}

function install_bloonix_webgui() {
  apt-get -qq -y install bloonix-webgui
  echo "include /etc/bloonix/webgui/nginx.conf;" > /etc/bloonix/webgui/nginx.conf
  systemctl restart nginx.service
  initialize_mysql_database
  initialize_elasticsearch
  systemctl restart bloonix-webgui.service
}

function install_bloonix_server() {
  apt-get -qq -y install bloonix-server
  systemctl start bloonix-server.service
}

function install_bloonix_plugins() {
  apt-get -qq -y install bloonix-plugins-* bloonix-plugin-config
  bloonix-load-plugins --load-all
}

function install_bloonix_agent() {
  apt-get -qq -y install bloonix-agent
}

install_dependencies
bloonix-repository
elasticsearch_repository
install_mysql-server
install_nginx
initialize_mysql_database
set_mysql_root_pw
initialize_elasticsearch
install_bloonix_webgui
install_bloonix_server
install_bloonix_plugins
install_bloonix_agent

echo -e "Your bloonix-instance should be up and running."
echo -e "Please check with your browser."
echo -e "Initial Login for Bloonix is: admin/admin"
echo -e "Happy monitoring!"
