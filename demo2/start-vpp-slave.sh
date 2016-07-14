#!/bin/bash
set -x

# SSVMEthernet Pairs need to know if they are the master or the slave on VPP Startup
# This is the SLAVE config

#
# Docker by default mounts a new per-container /dev/shm
# ... this blocks access to any file-level "-v /dev/shm/file:/dev/shm/file" style docker mount from the host
# ... which we need for the ssvm_eth device shared memory. Unmounting the containers /dev/shm mount exposes dockers real mount (All kinds of docker behaviour weirdness with /dev/shm & mounts)
#
#umount -lf /dev/shm
sleep 2
vpp unix {cli-listen 0.0.0.0:5002 startup-config /home/vagrant/vpe-ssvm-slave.conf } ssvm_eth {ssvmtest1 slave} dpdk {no-pci} &
