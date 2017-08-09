#!/bin/sh

. perf_env.sh

if [ $# -ne 2 ]
then
   echo "Specify two files: src_file dst_file"
   exit 1
fi

gen_percent_tbl $1 $2
