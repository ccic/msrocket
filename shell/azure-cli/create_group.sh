#!/bin/sh
if [ $# -lt 1 ]
then
   echo "Specify the group_name <location>"
   echo "    the default location is 'eastasia', you can use 'azure locatin list' to get your expected location"
   exit 1
fi
group_name=$1
location="eastasia"
if [ $# -eq 2 ]
then
   location=$2
fi
azure group create "$group_name" "$location"
