#!/bin/sh

. perf_env.sh

if [ $# -ne 3 ]
then
   echo "Specify two files: src_file dst_file storage_prefix"
   exit 1
fi

src_file=$1
dst_file=$2
storage_prefix=$3

compare2fio
