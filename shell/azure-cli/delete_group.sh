#!/bin/sh
if [ $# -ne 1 ]
then
   echo "Specify the group name"
   exit 1
fi
group_name=$1
azure group delete $group_name --json
