#!/bin/bash
cat > /etc/hosts << EOT
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.25.1.101 node01.uplooking.com node01
172.25.1.102 node02.uplooking.com node02
172.25.1.103 node03.uplooking.com node03
172.25.1.104 node04.uplooking.com node04
172.25.1.105 node05.uplooking.com node05
172.25.1.106 node06.uplooking.com node06
172.25.1.107 node07.uplooking.com node07
172.25.1.108 node08.uplooking.com node08
172.25.1.109 node09.uplooking.com node09
172.25.1.110 node10.uplooking.com node10
EOT

hostname node$1.uplooking.com
cat > /etc/sysconfig/network << EOT
NETWORKING=yes
HOSTNAME=node$1.uplooking.com
EOT

IP=$(cat /etc/hosts |grep node$1 |cut -d"." -f4 |cut -d" " -f1)
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOT
DEVICE="eth0"
TYPE=Ethernet
BOOTPROTO="static"
ONBOOT="yes"
IPADDR=172.25.1.$IP
NETMASK=255.255.255.0
GATEWAY=172.25.1.254
EOT

IP=$(cat /etc/hosts |grep node$1 |cut -d"." -f4 |cut -d" " -f1)
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<EOT
DEVICE="eth1"
TYPE=Ethernet
BOOTPROTO="static"
ONBOOT="yes"
IPADDR=192.168.122.$IP
NETMASK=255.255.255.0
EOT

mkdir -p /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsrB1sOR7VblNfIfWWwBTLHZtS6s1d2r+wh1CDerg0y9j3SU7vf070q+1hKpD977yza221yTJW7iYj7l39yQJBdDyOBas44UlGRv78bku9Ts0myub6lwPSYZjxBRR3hIXMz7skqTg58nbIfVfAteHUf3BVa4T2SkXuhCnO25NE6NouDA0bVAPVafT9m++tBrTLJ2n+gtrF0+7s38iZzSCvMsMtIKdCYDL4wI5aXminDuo7KldCLMScs9y3n5D2uSM5poBPd3ZNgdnPWGxChn0a+LoBnWKN4EjmUH8WWbmES8T603gKjk2zS/7ZVgfwnRDjH82eAQUGXKFwdwuXB1jP root@foundation21.ilt.example.com" > /root/.ssh/authorized_keys

reboot





