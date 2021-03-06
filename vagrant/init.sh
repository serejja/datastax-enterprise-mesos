#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

install_ssh_keys() {
  # own key
  cp .vagrant/`hostname`_key.pub /home/vagrant/.ssh/id_rsa.pub
  cp .vagrant/`hostname`_key /home/vagrant/.ssh/id_rsa
  chown vagrant:vagrant /home/vagrant/.ssh/id_rsa*

  # other hosts keys
  cat .vagrant/*_key.pub >> /home/vagrant/.ssh/authorized_keys
}

install_mesos() {
    mode=$1 # master | slave
    apt-get -qy install mesos=0.25.0*

    echo "zk://master:2181/mesos" > /etc/mesos/zk
    echo '10mins' > /etc/mesos-slave/executor_registration_timeout
    echo 'cpus:1;mem:2500;ports:[5000-32000]' > /etc/mesos-slave/resources

    ip=$(cat /etc/hosts | grep `hostname` | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    echo $ip > "/etc/mesos-$mode/ip"

    if [ $mode == "master" ]; then
        ln -s /lib/init/upstart-job /etc/init.d/mesos-master
        service mesos-master start
    else
        apt-get -qy remove zookeeper
    fi

    ln -s /lib/init/upstart-job /etc/init.d/mesos-slave
    service mesos-slave start
}

install_marathon() {
    apt-get install -qy marathon=0.10.0*
    service marathon start
}

install_docker() {
    apt-get install -qy lxc-docker
    echo 'docker,mesos' > /etc/mesos-slave/containerizers
    service mesos-slave restart
}

install_cassandra() {
    apt-get install dsc21=2.1.11-1 cassandra=2.1.11 -y --force-yes
    service cassandra stop
    rm -rf /var/lib/cassandra/data/system/*

    CASSANDRA_CFG=/etc/cassandra/cassandra.yaml
    cp $CASSANDRA_CFG ${CASSANDRA_CFG}.bak
    sed "s/- seeds:.*/- seeds: \"master\"/" $CASSANDRA_CFG > /tmp/cass.1.yaml
    sed "s/listen_address:.*/listen_address: /" /tmp/cass.1.yaml > /tmp/cass.2.yaml
    sed "s/rpc_address:.*/rpc_address: /" /tmp/cass.2.yaml > $CASSANDRA_CFG

    service cassandra start
    sleep 30
    cqlsh master -f /vagrant/vagrant/cassandra_schema.cql
}

install_opscenter() {
    apt-get install -qy sysstat opscenter=5.2.2
    service opscenterd start
}

if [[ $1 != "master" && $1 != "slave" ]]; then
    echo "Usage: $0 master|slave"
    exit 1
fi
mode=$1

cd /vagrant/vagrant

# name resolution
cp .vagrant/hosts /etc/hosts

install_ssh_keys

# disable ipv6
echo -e "\nnet.ipv6.conf.all.disable_ipv6 = 1\n" >> /etc/sysctl.conf
sysctl -p

# use apt-proxy if present
if [ -f ".vagrant/apt-proxy" ]; then
    apt_proxy=$(cat ".vagrant/apt-proxy")
    echo "Using apt-proxy: $apt_proxy";
    echo "Acquire::http::Proxy \"$apt_proxy\";" > /etc/apt/apt.conf.d/90-apt-proxy.conf
fi

# add mesosphere repo
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | tee /etc/apt/sources.list.d/mesosphere.list

# add datastax repo
echo "deb http://debian.datastax.com/community stable main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
curl -L http://debian.datastax.com/debian/repo_key | sudo apt-key add -

# add docker repo
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
echo "deb http://get.docker.com/ubuntu docker main" > /etc/apt/sources.list.d/docker.list

apt-get -qy update

# install deps
apt-get install -qy vim zip mc curl wget openjdk-7-jre scala git

install_mesos $mode
if [ $mode == "master" ]; then
    install_marathon
#    install_opscenter
#    install_cassandra
fi
#install_docker