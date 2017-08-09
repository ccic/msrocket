#!/bin/sh
## Suppose there are 2 NICs
## run this script with root
if [ $# -ne 1 ]
then
   echo "Specify <internal_ip>"
   exit 1
fi
inter_ip=$1

is_inter_ip0=`ifconfig hn0|grep $inter_ip`
is_inter_ip1=`ifconfig hn1|grep $inter_ip`
if [ "$is_inter_ip0" != "" ] || [ "$is_inter_ip1" != "" ]
then
   echo "Internal IP is already set"
   exit 0
fi

is_corp_ip=`ifconfig hn0|grep netmask`
if [ "$is_corp_ip" == "" ]
then
   ifconfig hn0 ${inter_ip}
else
   ifconfig hn1 ${inter_ip}
fi
exit 0
