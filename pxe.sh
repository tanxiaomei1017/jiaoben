#!/bin/bash
yum -y install httpd &> /dev/null && echo "httpd安装已经成功了！"
#设置serverg服务器关闭eth0 设置eth1的网关
  
cat > /etc/sysconfig/network-scripts/ifcfg-eth1 << END
DEVICE=eth1
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
USERCTL=yes
IPV6INIT=no
IPADDR=192.168.0.16
GATEWAY=192.168.0.10
NETMASK=255.255.255.0
END

#关闭桥接网络:
sed -i 's/^ONBOOT.*/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0
systemctl restart network
 
#注意:关闭selinux与iptables
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 
echo "/sbin/setenforce 0" >> /etc/rc.local 
chmod +x /etc/rc.local 
source  /etc/rc.local 
  
#下载iso ，发布iso，配置yum源 
mkdir -p /yum
mkdir -p /rhel6u5
  
cat >> /etc/fstab << END
172.25.254.250:/content /mnt    nfs ro  0 0
/mnt/rhel6.5/x86_64/isos/rhel-server-6.5-x86_64-dvd.iso  /rhel6u5 iso9660 ro 0 0
/mnt/rhel7.2/x86_64/isos/rhel-server-7.2-x86_64-dvd.iso  /yum iso9660 ro 0 0
END
mount -a  

cd /etc/yum.repos.d/
find . -regex '.*\.repo$' -exec mv {} {}.back \;

cat > /etc/yum.repos.d/local.repo << END
[local]
baseurl=file:///yum
gpgcheck=0
END

# 搭建DHCP

yum -y install dhcp &> /dev/null && echo "DHCP安装已经成功了！"


\cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example  /etc/dhcp/dhcpd.conf

cat > /etc/dhcp/dhcpd.conf << EOT
allow booting;
allow bootp;

option domain-name "pod21.example.com";
option domain-name-servers 172.25.254.254;
default-lease-time 600;
max-lease-time 7200;

log-facility local7;

subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.50 192.168.0.60;
  option domain-name-servers 172.25.254.254;
  option domain-name "pod0.example.com";
  option routers 192.168.0.10;
  option broadcast-address 192.168.0.255;
  default-lease-time 600;
  max-lease-time 7200;
  next-server 192.168.0.16;
  filename "pxelinux.0";
}
EOT
systemctl start dhcpd && netstat -unlp |grep :67 && echo "dhcp启动ok！"


#第四步: TFTP

yum -y install tftp-server &> /dev/null && echo "tftp-server安装已经成功了!" 
yum -y install syslinux &> /dev/null && echo "syslinux安装已经成功了!" 
yum -y install xinetd &> /dev/null && echo "xinetd安装已经成功了！" 


 
\cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/
cd /var/lib/tftpboot/
mkdir -p pxelinux.cfg
cd pxelinux.cfg
touch default
mkdir /var/lib/tftpboot/pxelinux.cfg -p

# 生成标签（内核与ks文件）
cat > /var/lib/tftpboot/pxelinux.cfg/default <<EOT
default vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!

label local
        menu label Boot from ^local drive
        menu default
        localhost 0xffff

label install
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://192.168.0.16/myks.cfg

label install6
        menu label Install rhel6u5
        kernel rhel6u5/vmlinuz
        append initrd=rhel6u5/initrd.img ks=http://192.168.0.16/rhel6u5_ks.cfg
EOT

#生成引导相关文件
cd /yum/isolinux
\cp splash.png vesamenu.c32 vmlinuz initrd.img /var/lib/tftpboot/
sed -i 's/^disable .*/disable                 = no/' /etc/xinetd.d/tftp 

systemctl start xinetd && netstat -unlp |grep :69 && echo "发现69号端口"
  
#生成ks.cfg文件并发布
cd /var/lib/tftpboot/
cat > /var/www/html/myks.cfg << END
#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
# Reboot after installation 
reboot
# Use network installation
url --url="http://192.168.0.16/rhel7u2/"
# Use graphical install
#graphical 
text
# Firewall configuration
firewall --enabled --service=ssh
firstboot --disable 
ignoredisk --only-use=vda
# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us' 
# System language 
lang en_US.UTF-8 
# Network information
network  --bootproto=dhcp
network  --hostname=localhost.localdomain
#repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope 

# SELinux configuration
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rsyslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda 
# 设置boot loader安装选项 --append指定内核参数 --location 设定引导记录的位置
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144
%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end

%packages
@core
%end
END


touch /var/www/html/rhel6u5_ks.cfg
cat > /var/www/html/rhel6u5_ks.cfg << END
 #platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use network installation
url --url="http://192.168.0.16/rhel6u5"
# Root password
rootpw --plaintext redhat
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --disabled
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone --isUtc Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel 
# Disk partitioning information
part /boot --fstype="ext4" --size=200
part / --fstype="ext4" --size=9000
part swap --fstype="swap" --size=1024

%pre
clearpart --all
part /boot --fstype ext4 --size=100
part pv.100000 --size=10000
part swap --size=512
volgroup vg --pesize=32768 pv.100000
logvol /home --fstype ext4 --name=lv_home --vgname=vg --size=480
logvol / --fstype ext4 --name=lv_root --vgname=vg --size=8192
%end


%post
touch /tmp/abc
%end

%packages
@base
@chinese-support
tigervnc
openssh-clients

%end
END

#定义当前系统的内核文件 (vmlinuz/initrd)
mkdir /var/lib/tftpboot/rhel6u5 -p
cd /rhel6u5
cd isolinux
\cp vmlinuz initrd.img /var/lib/tftpboot/rhel6u5/
chown apache /var/www/html/myks.cfg

ln -s /yum/ /var/www/html/rhel7u2 &> /dev/null
ln -s /rhel6u5/ /var/www/html/rhel6u5 &> /dev/null
wget  http://127.0.0.1/rhel6u5/media.repo &>/dev/null  &&  echo "发布成功"
 
service httpd restart
service xinetd restart
service dhcpd restart
systemctl enable xinetd &> /dev/null
systemctl enable httpd &> /dev/null
systemctl enable dhcpd &> /dev/null



 
 
 
 
 
 
