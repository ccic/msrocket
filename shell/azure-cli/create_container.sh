#!/bin/sh
if [ $# -ne 3 ]
then
  echo "Specify group_name storage_account_name expected_container_name"
  exit 1
fi
group_name=$1
storage_name=$2
container_name=$3
container_permission=Blob # the storage container ACL permission(Off/Blob/Container)
key=`azure storage account keys list -g $group_name $storage_name --json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["key1"]'`
azure storage container create -p $container_permission -a $storage_name -k $key -vv --json $container_name
