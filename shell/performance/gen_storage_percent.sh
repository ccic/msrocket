#!/bin/sh
. perf_env.sh

if [ $# -ne 2 ]
then
   echo "Specify two csv files which contains the: src_csv, dst_csv"
   exit 1
fi

src_file=$1
dst_file=$2

gen_percentage_for_storage $src_file $dst_file
