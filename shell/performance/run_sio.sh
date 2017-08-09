#!/bin/sh

log() {
   local msg="$1"
   local log_tag="SIO"
   logger -t $log_tag "$msg"
}

derefer_2vars() {
   local prefix=$1
   local postfix=$2
   local v=${prefix}${postfix}
   eval echo \$${v}
}

if [ $# -ne 2 ]
then
   echo "Specify output_dir and sio_env script file"
   exit 1
fi
outdir=$1
sio_script=$2
result_folder=$outdir
sio_prefix="sio"

. ./$sio_script

if [ ! -d $outdir ]
then
   mkdir $outdir
fi

LOGFILE=${result_folder}/${sio_log_file}
iter=1
for bs in $sio_block_size_list
do
    blocksize=${bs}
    for mode in $sio_modes
    do
        digit_mode=$(derefer_2vars "sio_" $mode)
        for th in $sio_thread_list
        do
           jobname=job${iter}
           sio_output_file=${sio_prefix}-${jobname}-${mode}-${blocksize}-${th}.out
	   iostat_file=$result_folder/${sio_iostat_prefix}-${jobname}-${mode}-${blocksize}-${th}.txt
	   topstat_file=$result_folder/${sio_topstat_prefix}-${jobname}-${mode}-${blocksize}-${th}.txt
	   nohup iostat -x 5 > $iostat_file &
           iostatPID=$!
	   nohup sh $top_monitor_sh $topstat_file $sio_runtime &
	   topstat_pid=$!
	   echo "-- iteration on ${sio_server_ip}:${sio_server_port} job${iter} testmode:${mode} thread:${th} blocksize:${blocksize} --$(date +"%x %r %Z")" >> $LOGFILE
           log "$sio_drv $digit_mode ${blocksize} $sio_size $sio_runtime $th $sio_filename -direct > $result_folder/$sio_output_file"
           sio_cmd="$sio_drv $digit_mode ${blocksize} $sio_size $sio_runtime $th $sio_filename -direct > $result_folder/$sio_output_file"
	   echo "$sio_cmd" >> $LOGFILE
	   eval "$sio_cmd"
	   kill -9 $iostatPID
	   kill -0 $topstat_pid
	   if [ $? -eq 0 ]
	   then
	      kill -s TERM $topstat_pid
	   fi
           iter=`expr $iter + 1`
        done
    done
done
