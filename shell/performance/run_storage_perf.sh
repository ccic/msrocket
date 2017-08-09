#!/bin/sh
. perf_env.sh

log_level=2
if [ $# -ne 2 ]
then
   echo "Specify remote_ip out_dir"
   exit 1
fi

create_tmp_dir_ifnotexist

target_remote_ip=$1
out_dir=$2
if [ ! -d $out_dir ]
then
   mkdir $out_dir
fi
setup_device_fs ${target_remote_ip}
run_fio ${target_remote_ip} $out_dir
#run_sysbench ${target_remote_ip} $out_dir

