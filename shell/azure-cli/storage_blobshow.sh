#!/bin/sh

if [ $# -ne 3 ]
then
   echo "Specify group_name storage_account_name container_name"
   exit 1
fi
group_name=$1
storage_name=$2
container_name=$3
key=`azure storage account keys list -g $group_name $storage_name --json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["key1"]'`

azure storage blob show -a $storage_name --container $container_name -k $key --json -vv
