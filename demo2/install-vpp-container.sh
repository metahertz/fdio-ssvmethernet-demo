#!/bin/bash

echo "Installing VPP into container..."
cp -f /vagrant/demo2/sources.list /etc/apt/sources.list
apt-get update
apt-get install -y iputils-ping
apt-get install -y libssl1.0.0
dpkg -i /home/vagrant/dkms*.deb
dpkg -i /vagrant/debs/vpp*.deb
echo "Done installing VPP into container..."
