#!/bin/sh
if [ $# -ne 2 ]
then
   echo "Specify group_name storage_account"
   exit 1
fi
group_name=$1
storage_name=$2
sub_id=`sh get_subscription_id.sh`
azure storage account delete -g $group_name -s $sub_id $storage_name
