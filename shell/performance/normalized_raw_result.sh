#!/bin/sh
if [ $# -ne 1 ]
then
   echo "Specify the raw file"
   exit 1
fi

input=$1
line=`grep "SUM" $input| wc -l | awk '{print $1-2}'`
grep "SUM" $input|head -n $line|awk '{print $6}'|ministat
