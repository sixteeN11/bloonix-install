#!/bin/bash

# Simple check if this is a debian based distribution
if [ -f /etc/ddsadebian_version ]; then
  echo -e "Starting Bloonix-Installation..."
else
  echo -e "This is not a debian based distribution!"
  echo -e "Please use this script only on debian based distributions."
  echo -e "Aborting..."
  exit 1
fi

function install_dependencies {
  apt-get install -y apt-transport-https ca-certificates pwgen
}

function bloonix_repository {
  # Adding Bloonix-Repository
  wget -q -O- https://download.bloonix.de/repos/debian/bloonix.gpg | apt-key add -
  echo "deb https://download.bloonix.de/repos/debian/ jessie main" >> /etc/apt/sources.list.d/bloonix.list
  apt-get update
}

function elasticsearch_repository {
  # Adding elasticsearch-Repository
  wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add -
  echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" >> /etc/apt/sources.list.d/elasticsearch.list
  apt-get update
}

function install_mysql-server {
  # Installating MySQL-Server from debian-repositories and setting root password
  MYSQL_PASSWORD=`pwgen 12`
  debconf-set-selections <<< 'mysql-server mysql-server/root_password $MYSQL_PASSWORD $MYSQL_PASSWORD'
  debconf-set-selections <<< 'mysql-server mysql-server/root_password_again $MYSQL_PASSWORD $MYSQL_PASSWORD'
  apt-get install -y  mysql-server
  echo $MYSQL_PASSWORD > /root/MYSQL_PASSWORD.txt
}

function install_nginx {
  apt-get install -y nginx
  sed -i 's/.*server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/' /etc/nginx/nginx.conf
}

function initialize_mysql_database {
  /srv/bloonix/webgui/schema/init-database --mysql
}

function initialize_elasticsearch {
  /srv/bloonix/webgui/schema/init-elasticsearch localhost:9200
}

function install_bloonix_webgui {
  apt-get install -y bloonix-webgui
  echo "include /etc/bloonix/webgui/nginx.conf;" > /etc/bloonix/webgui/nginx.conf
  systemctl restart nginx.service
  initialize_mysql_database
  initialize_elasticsearch
  systemctl restart bloonix-webgui.service
}

function install_bloonix_server {
  apt-get install -y bloonix-server
  systemctl start bloonix-server.service
}

function install_bloonix_plugins {
  apt-get install -y bloonix-plugins-* bloonix-plugin-config
  bloonix-load-plugins --load-all
}

function install_bloonix_agent {
  apt-get install -y bloonix-agent
}
