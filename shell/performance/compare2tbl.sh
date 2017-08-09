#!/bin/sh

. perf_env.sh

if [ $# -ne 2 ]
then
   echo "Specify two files: src_file dst_file"
   exit 1
fi

compare2nic $1 $2
