#!/bin/bash

read -p "请输入主机的名称:" CG


if  [ -f /etc/libvirt/qemu/$CG.xml ] 
then
  virsh destroy $CG
  virsh undefine $CG
  rm -fr /var/lib/libvirt/images/$CG.*
fi

  virt-clone -o rhel6.5 -n $CG -f /var/lib/libvirt/images/$CG.img
  sed -i "s/domain-rhel6.5/domain-$CG/" /etc/libvirt/qemu/$CG.xml 
  virsh define /etc/libvirt/qemu/$CG.xml
  virsh start $CG 

