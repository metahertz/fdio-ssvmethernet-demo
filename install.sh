#!/usr/bin/env bash

sysctl -w vm.nr_hugepages=1024
HUGEPAGES=`sysctl -n  vm.nr_hugepages`
if [ $HUGEPAGES != 1024 ]; then
    echo "ERROR: Unable to get 1024 hugepages, only got $HUGEPAGES.  Cannot finish."
    exit
fi

echo "deb https://nexus.fd.io/content/repositories/fd.io.master.ubuntu.trusty.main/ ./" | sudo tee -a /etc/apt/sources.list.d/99fd.io.list
apt-get -qq update
apt-get -qq install -y --force-yes vpp vpp-dpdk-dkms
apt-get -qq install -y docker.io tmux uuid
service vpp start
