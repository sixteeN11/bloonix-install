#!/bin/bash

# Version 1.1.1
# This small script automates the installation
# of the bloonix monitoring-suite
# more information: https://github.com/dominicpratt/bloonix-install
# Author: Dominic Pratt (https://dominicpratt.de)

# init vars

MYSQL_PASSWORD=""

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
  echo -en "Installing dependencies .. "
  apt-get -qq remove apt-listchanges > /dev/null && \
  apt-get -qq update > /dev/null && \
  apt-get -qq install apt-transport-https ca-certificates pwgen curl ca-certificates-java lsb-release > /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

bloonix_repository() {
  echo -ne "Adding Bloonix-Repository .. "
  wget -q -O- https://download.bloonix.de/repos/debian/bloonix.gpg | apt-key add - > /dev/null && \
  echo "deb https://download.bloonix.de/repos/debian/ `lsb_release --codename | cut -f2` main" >> /etc/apt/sources.list.d/bloonix.list && \
  apt-get -qq update
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

elasticsearch_repository() {
  echo -ne "Adding elasticsearch-Repository .. "
  wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | apt-key add - > /dev/null && \
  echo "deb https://packages.elastic.co/elasticsearch/2.x/debian stable main" >> /etc/apt/sources.list.d/elasticsearch.list && \
  apt-get -qq update && \
  apt-get -qq install elasticsearch > /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

install_mysql_server() {
  echo -en "Installating MySQL-Server from debian-repositories and setting root password .. "
  MYSQL_PASSWORD=`pwgen 12`
  echo mysql-server mysql-server/root_password password $MYSQL_PASSWORD | debconf-set-selections && \
  echo mysql-server mysql-server/root_password_again password $MYSQL_PASSWORD | debconf-set-selections && \
  apt-get -qq install mysql-server > /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
 echo $MYSQL_PASSWORD > /root/MYSQL_PASSWORD.txt
}

install_nginx() {
  echo -en "Installing nginx .. "
  apt-get -qq install nginx > /dev/null && \
  sed -i'.bak' 's/.*server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/' /etc/nginx/nginx.conf
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

initialize_mysql_database() {
  echo -en "Initialize MySQL-Database schema .. "
  echo "${MYSQL_PASSWORD}" | /srv/bloonix/webgui/schema/init-database --mysql > /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

initialize_elasticsearch() {
  echo -en "Initialize Elasticsearch-Schema .. "
  sed -i'.bak' 's/.*network.host:.*/network.host: 127.0.0.1/' /etc/elasticsearch/elasticsearch.yml && \
  service elasticsearch start && \
  sleep 30 && \
  /srv/bloonix/webgui/schema/init-elasticsearch localhost:9200 > /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

install_bloonix_webgui() {
  echo -en "Install Bloonix WebGUI .. "
  apt-get -qq install bloonix-webgui > /dev/null && \
  echo "include /etc/bloonix/webgui/nginx.conf;" > /etc/nginx/conf.d/bloonix.conf && \
  service nginx restart && \
  service bloonix-webgui restart
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

install_bloonix_server() {
  echo -en "Install Bloonix Server .. "
  apt-get -qq install bloonix-server > /dev/null && \
  service bloonix-server restart
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

install_bloonix_plugins() {
  echo -en "Install all Bloonix Plugins and load them .. "
  apt-get -qq install bloonix-plugins-* bloonix-plugin-config > /dev/null && \
  bloonix-load-plugins --load-all > /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
}

install_bloonix_agent() {
  echo -en "Install Bloonix Agent .. "
  apt-get -qq install bloonix-agent > /dev/null
  if [ "$?" -ne 0 ]; then
    echo -e "failed."
    exit 1
  else
    echo -e "done."
  fi
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
echo -e ""
echo -e "Initial Login for Bloonix is: admin/admin"
echo -e ""
echo -e "For further documentation on Bloonix please look at https://bloonix.org/de/docs/about/about.html"
echo -e ""
echo -e "Your root password for MySQL is "\"$MYSQL_PASSWORD\" "and is saved to /root/MYSQL_PASSWORD.txt"
echo -e "Happy monitoring!"
