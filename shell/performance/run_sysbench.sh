#!/bin/sh

log() {
   local msg="$1"
   local log_tag="SYSBENCH"
   logger -t $log_tag "$msg"
}
## param1: output_dir
## param2: env script
run_sysbench() {
    local output_dir=$1
    local thread_no
    local io_size
    local iostat_file
    local iostatPID
    local iteration=1

    echo "1: $output_dir"    
    echo "2: $sysbench_common_options"
    echo "3: $sysbench_modes"
    echo "4: $sysbench_thread_list"
    echo "5: $sysbench_block_size_list"
    echo "6: $working_dir"
    echo "7: $iostat_prefix"
    echo "8: $sysbench_log_file"
    cd $working_dir

    if [ ! -d $output_dir ]
    then
       mkdir $output_dir
    fi

    local LOGFILE=$output_dir/$sysbench_log_file
    # Remove any old files from prior runs (to be safe), then prepare a set of new files.
    sysbench $sysbench_common_options cleanup
    echo "--- Disk Usage Before Generating New Files ---" >> $LOGFILE
    df -h >> $LOGFILE
    sysbench $sysbench_common_options prepare
    echo "--- Disk Usage After Generating New Files ---" >> $LOGFILE
    df -h >> $LOGFILE
    echo "=== End Preparation  $(date +"%x %r %Z") ===" >> $LOGFILE

    for testmode in $sysbench_modes; do
	for thread_no in $sysbench_thread_list
	do
	    for io_size in $sysbench_block_size_list
	    do
		topstat_file=${sysbench_topstat_prefix}-${testmode}-${thread_no}-${io_size}K.txt
		iostat_file=${iostat_prefix}-${testmode}-${thread_no}-${io_size}K.txt
		nohup iostat -x 5 > $output_dir/$iostat_file &
                iostatPID=$!
		nohup sh $top_monitor_sh $topstat_file $sysbench_runtime &
		topstat_pid=$!
		sysbench_cmd="sysbench $sysbench_common_options --file-test-mode=$testmode --file-block-size=${io_size}K --num-threads=$thread_no run"
		echo "-- iteration ${iteration} ------------------------${sysbench_remote_ip}:${sysbench_remote_port}, ${testmode}, ${Thread} threads, ${io_size}K ------------------ $(date +"%x %r %Z") ---" >> $LOGFILE
		echo "$sysbench_cmd" >> $LOGFILE
		sysbench_result=$output_dir/sysbench-${testmode}-${thread_no}-${io_size}K.result
		eval "$sysbench_cmd" > $sysbench_result
		kill -9 $iostatPID
		kill -s TERM $topstat_pid
                iteration=`expr $iteration + 1`
	    done
	done
    done
    sysbench $sysbench_common_options cleanup
}

if [ $# -ne 2 ]
then
   echo "Specify output_dir env_script_file"
   exit 1
fi
output_dir=$1
env_script_file=$2
. ./$env_script_file
run_sysbench $output_dir
