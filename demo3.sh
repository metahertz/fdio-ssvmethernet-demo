#!/usr/bin/env bash

if [ $USER != "root" ] ; then
    #echo "Restarting script with sudo..."
    sudo $0 ${*}
    exit
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function pause {
    echo ""; echo ""
    read -n1 -r -p "Press space to continue..." key
    printf "\033c"
}

function instruction {

    echo ""
    echo -e "${RED}********************************************************************************${NC} \n"
    echo -e " ${RED}$1${NC}"
    echo -e " ${GREEN}$2${NC} \n"
    echo -e "${RED}********************************************************************************${NC} \n"

    if [ -z "$2" ]
    then
    echo "No commands to run here."
    else
    echo "Running!"
    eval $2
    fi

}

exposedockernetns () {
	if [ "$1" == "" ]; then
  	  echo "usage: $0 <container_name>"
	  echo "Exposes the netns of a docker container to the host"
          exit 1
        fi

        pid=`docker inspect -f '{{.State.Pid}}' $1`
        ln -s /proc/$pid/ns/net /var/run/netns/$1

        echo "netns of ${1} exposed as /var/run/netns/${1}"
   return 0
}

dockerrmf () {
	#Cleanup demo3 containers on the host (dead or alive).
	docker kill `sudo docker ps --no-trunc -aq -f name=ssvm`  ; docker rm `sudo docker ps --no-trunc -aq -f name=ssvm`
}

mkdir /var/run/netns >/dev/null 2>&1
find / -name dkms*.deb -exec cp  {} /home/vagrant/. \;

#Cleanup old runs of Demo3
rm -f /home/vagrant/vpe-ssvm-master.conf
rm -f /home/vagrant/vpe-ssvm-slave.conf
rm -f /home/vagrant/docker-vpe-start.sh
dockerrmf >/dev/null 2>&1
rm -f /var/run/netns/ssvm-master
rm -f /var/run/netns/ssvm-slave
#Cleanup and setup shared memory
rm -Rf /dev/shm/*
rm -Rf /dev/shm/ssvmtest1
touch /dev/shm/ssvmtest1
chmod 777 /dev/shm/ssvmtest1

instruction "Welcome to Demo3 - SSVM Ethernet between containers using AF_PACKET.
 This demo will show you the 'Shared Memory Ethernet' or SSVM interface.
 This can link two VPP instances together via the hosts shared memory.
 We are also using AF_PACKET for VPP to Kernel connectivity, compared to TUNTAP in Demo2. "
pause

instruction "This Demo will create two docker containers. Each running an instance of VPP within.
 We will then network the two containers together via ssvmEthernet
 and also create a 'regular' interface in each container.
 Running pings will then allow each container to communicate with eachother.
 A topology diagram is available in this repo under the 'Demo3' directory. "


pause

instruction "Lets create two docker containers. Running a simple ubuntu image.
 The file /dev/shm/ssvmtest1 from the host will be shared between both." "docker pull ubuntu;
 docker run --name "ssvm-master" --privileged --cap-add SYS_ADMIN --cap-add NET_ADMIN -v /vagrant:/vagrant -v /home/vagrant:/home/vagrant -v /dev/shm/ssvmtest1:/dev/shm/ssvmtest1  -v /dev/net:/dev/net ubuntu sleep 30000 &
 docker run --name "ssvm-slave"  --privileged --cap-add SYS_ADMIN --cap-add NET_ADMIN -v /vagrant:/vagrant -v /home/vagrant:/home/vagrant -v /dev/shm/ssvmtest1:/dev/shm/ssvmtest1  -v /dev/net:/dev/net ubuntu sleep 30000 &
 sleep 5;
 exposedockernetns ssvm-master;
 exposedockernetns ssvm-slave
 "


pause

instruction "Check the containers are up and find their IP addresses" "
echo "Container1:";
docker inspect --format '{{ .NetworkSettings.IPAddress }}' ssvm-master;
echo "Container2:";
docker inspect --format '{{ .NetworkSettings.IPAddress }}' ssvm-slave
"

pause

instruction "Install the VPP debian packages into our containers." "
docker exec ssvm-master /vagrant/demo3/install-vpp-container.sh;
docker exec ssvm-slave /vagrant/demo3/install-vpp-container.sh
"

pause

instruction "Create an AF_PACKET interface within each container NetNS for VPP to bind." "
ip netns exec ssvm-master ip link add vpp0 type veth peer name vethns0;
ip netns exec ssvm-slave ip link add vpp1 type veth peer name vethns1;
ip netns exec ssvm-master ip link set vethns0 up;
ip netns exec ssvm-master ip link set vpp0 up;
ip netns exec ssvm-slave ip link set vethns1 up;
ip netns exec ssvm-slave ip link set vpp1 up;

"
pause

instruction "View the configuration files for each VPP instance.
 Notice each side of the SSVMethernet link, and then different subnets
 for the foobar interface on each container. We'll be routing between containers! " "
echo MASTER CONFIG: ;
cat /vagrant/demo3/vpe-ssvm-master.conf;
cp /vagrant/demo3/vpe-ssvm-master.conf /home/vagrant/vpe-ssvm-master.conf;
echo SLAVE CONFIG: ;
cat /vagrant/demo3/vpe-ssvm-slave.conf;
cp /vagrant/demo3/vpe-ssvm-slave.conf /home/vagrant/vpe-ssvm-slave.conf;
"
pause

instruction "Start our VPP Instances" "
docker exec ssvm-master /vagrant/demo3/start-vpp-master.sh;
docker exec ssvm-slave /vagrant/demo3/start-vpp-slave.sh;

"

pause

instruction "Check VPP is running by connecting to the console and viewing VPP interfaces " "
docker exec ssvm-master vppctl sh int;
docker exec ssvm-slave vppctl sh int;

"

pause

instruction "We can also see the FIB, with the IP addresses we added to our VPP startup configurations." "
docker exec ssvm-master vppctl show ip fib;

docker exec ssvm-slave vppctl show ip fib;

"

pause

instruction "Those TAP interfaces in VPP, the other end of them is within the container as Linux network interfaces.
We can assign IP addresses to them to allow VPP to route traffic to its own container." "
ip netns exec ssvm-master ip addr add 192.168.1.2/24 dev vethns0;
ip netns exec ssvm-master ip route add 10.1.1.0/24 via 192.168.1.1;
ip netns exec ssvm-master ip route add 192.168.2.0/24 via 192.168.1.1

"

instruction "The container ssvm-master can now ping its own VPP...  " "
echo Show container IP addresses and routes;
ip netns exec ssvm-master ip route list;
ip netns exec ssvm-master ip addr list;
echo Ping our own VPP instance;
docker exec ssvm-master ping -c3 192.168.1.1;
docker exec ssvm-master ping -c3 10.1.1.1;

"

pause

instruction "And again for the second container..." "
ip netns exec ssvm-slave ip addr add 192.168.2.2/24 dev vethns1;
ip netns exec ssvm-slave ip route add 10.1.1.0/24 via 192.168.2.1;
ip netns exec ssvm-slave ip route add 192.168.1.0/24 via 192.168.2.1;
ip netns exec ssvm-slave ip route list;
ip netns exec ssvm-slave ip addr list;
docker exec ssvm-slave ping -c3 192.168.2.1;
docker exec ssvm-slave ping -c3 10.1.1.2;

"

pause

instruction "Add an IPTables rule to make sure we're not getting false positives. " "
ip netns exec ssvm-master iptables -A OUTPUT -p icmp -o eth0 -j REJECT;
ip netns exec ssvm-slave iptables -A OUTPUT -p icmp -o eth0 -j REJECT;

"

pause

instruction "Putting it all together! Lets ping the following path..
from Container1, via TAP to local VPP, via shared memory (SSVM) to Container2 VPP,
finally through container2 tap interface to the container itself. " "

echo 'Pinging Master container > foobar > VPP(master) > SSVMEthernet0 > VPP(Slave) > Foobar' ;
docker exec ssvm-master ping -c3 192.168.2.2;
echo 'Pinging Slave container > foobar > VPP(slave) > SSVMEthernet0 > VPP(master) > Foobar' ;
docker exec ssvm-slave ping -c3 192.168.1.2;
"

pause

instruction "Show the interface counters, special attention to the SSVMEthernet interface " "
docker exec ssvm-master vppctl sh int;
docker exec ssvm-slave vppctl sh int;

"

pause

instruction "Ping across the link a second time! Then we'll display counters again. " "

echo 'Pinging Master container > foobar > VPP(master) > SSVMEthernet0 > VPP(Slave) > Foobar' ;
docker exec ssvm-master ping -c3 192.168.2.2;
echo 'Pinging Slave container > foobar > VPP(slave) > SSVMEthernet0 > VPP(master) > Foobar' ;
docker exec ssvm-slave ping -c3 192.168.1.2;
docker exec ssvm-master vppctl sh int;
docker exec ssvm-slave vppctl sh int;

"

pause

instruction "Thanks it for demo3. all commands and scripts are within " " # /vagrant/demo3.sh"
