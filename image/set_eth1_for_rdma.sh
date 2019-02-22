#!/bin/bash
# This script need to be run on H16 to set ETH1 for Infiniband usage. 
# Usually done by waagent but this is broken by the kernel-devel needed to install Lustre on CentOS HPC 7.4 image

IP_ADDRESS=$(sed '/rdmaIPv4Address=/!d;s/.*rdmaIPv4Address="\([0-9.]*\)".*/\1/' /var/lib/waagent/SharedConfig.xml)
ifconfig eth1 ${IP_ADDRESS}/16
sed -i "s/ofa-v2-ib0 u2.0 nonthreadsafe default libdaplofa.so.2 dapl.2.0 \".*$/ofa-v2-ib0 u2.0 nonthreadsafe default libdaplofa.so.2 dapl.2.0 \"$IP_ADDRESS\" \"\"/g" /etc/rdma/dat.conf

ifconfig
