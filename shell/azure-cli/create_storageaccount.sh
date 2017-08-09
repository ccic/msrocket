#!/bin/sh
if [ $# -ne 2 ]
then
   echo "Specify group_name and expected_storage_name"
   exit 1 
fi
group_name=$1
storage_name=$2
location="eastasia" ## "azure location list" lists all the locations
storage_type="LRS"  ## LRS/ZRS/GRS/RAGRS/PLRS
azure storage account create -l $location --type $storage_type -g $group_name --json -vv $storage_name ## location can be "eastasia" or "east asia"
