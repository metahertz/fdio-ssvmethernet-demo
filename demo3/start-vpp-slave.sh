#!/bin/bash
set -x

# SSVMEthernet Pairs need to know if they are the master or the slave on VPP Startup
# This is the SLAVE config

sleep 2
vpp unix {cli-listen 0.0.0.0:5002 startup-config /home/vagrant/vpe-ssvm-slave.conf } ssvm_eth {ssvmtest1 slave} dpdk {no-pci} &
