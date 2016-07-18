#!/bin/bash
set -x

# SSVMEthernet Pairs need to know if they are the master or the slave on VPP Startup
# This is the MASTER config

sleep 2
vpp unix {cli-listen 0.0.0.0:5002 startup-config /home/vagrant/vpe-ssvm-master.conf } ssvm_eth {ssvmtest1} dpdk {no-pci} &
