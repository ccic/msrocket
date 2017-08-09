#!/bin/sh
. linux_perf_env.sh

if [ $# -ne 1 ]
then
   echo "Specify remote_ip"
   exit 1
fi

run_fio() {
    local output_dir=fio_`date +%Y%m%d%H%M%S`
    local remote_ip=$1
    scp run_fio.sh root@${remote_ip}:/home/test
    ssh root@${remote_ip} "su test;cd /home/test; sh run_fio.sh $output_dir \"$fio_common_options\" \"$fio_modes\" $fio_block_size_start $fio_block_size_max $fio_numjobs_start $fio_numjobs_max $fio_iostat_prefix $fio_prefix"
    scp -r root@${remote_ip}:/home/test/$output_dir .
}

run_sysbench() {
    local output_dir=sysbench_`date +%Y%m%d%H%M%S`
    local remote_ip=$1
    scp run_sysbench.sh root@${remote_ip}:/home/test
    log "cd /home/test; sh run_sysbench.sh $output_dir \"$sysbench_common_options\" \"$sysbench_modes\" $sysbench_thread_max $sysbench_thread_start $sysbench_block_size_max $sysbench_block_size_start $mount_target $sysbench_iostat_prefix > log"
    ssh root@${remote_ip} "su test; cd /home/test; sh run_sysbench.sh $output_dir \"$sysbench_common_options\" \"$sysbench_modes\" $sysbench_thread_max $sysbench_thread_start $sysbench_block_size_max $sysbench_block_size_start $mount_target $sysbench_iostat_prefix > log"
    scp -r root@${remote_ip}:$mount_target/$output_dir .
}
create_tmp_dir_ifnotexist
target_remote_ip=$1
run_fio $target_remote_ip
