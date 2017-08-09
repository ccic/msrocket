#!/bin/sh
log() {
   local msg="$1"
   local log_tag="FIOJOBS"
   logger -t $log_tag "$msg"
}

if [ $# -ne 2 ]
then
   echo "Specify output_dir and fio_env script file"
   exit 1
fi
outdir=$1
fio_script=$2
config_folder=$outdir
result_folder=$outdir
fio_prefix="fio"

. ./$fio_script ## arguments are passed from this environment file

if [ ! -d $outdir ]
then
   mkdir $outdir
fi

LOGFILE=${result_folder}/${fio_log_file}
log "fio_block_size_list: $fio_block_size_list"
log "fio_modes: $fio_modes"
log "fio_numjobs_list: $fio_numjobs_list"
server_ip=""

os=`uname`
if [ "$os" == "FreeBSD" ]
then
   server_ip=`ifconfig hn0 | grep "inet "|awk '{print $2}'`
   pkg info wget > /dev/null
   if [ $? -ne 0 ]
   then
      pkg install -y wget >> $LOGFILE
   fi
else
   if [ "$os" == "Linux" ]
   then
     server_ip=`ifconfig eth0 | grep "inet "|awk '{print $2}'`
   fi
fi

######## get external IP ######
   #ext_ip=`wget checkip.dyndns.org:80 -O - -o /dev/null | cut -d" " -f6 | sed 's/<\/body><\/html>//'`
   ext_ip=`wget --read-timeout=3 checkip.dyndns.org:80 -O - -o /dev/null| awk '{print $6}'| awk -F \< '{print $1}'`

iter=1
for bs in $fio_block_size_list
do
    blocksize=${bs}k
    for mode in $fio_modes
    do
	for iodepth in $fio_iodepth_list
	do
        	for th in $fio_numjobs_list
        	do
		jobname=job${iter}
		fio_output_file="${fio_prefix}-${jobname}-${mode}-${blocksize}-${iodepth}-${th}.json"
		fio_job_config="${fio_prefix}-${jobname}-${mode}-${blocksize}-${iodepth}-${th}.config"
		iostat_file=$result_folder/${fio_iostat_prefix}-${jobname}-${mode}-${blocksize}-${iodepth}-${th}.txt
		topstat_file=$result_folder/${fio_topstat_prefix}-${jobname}-${mode}-${blocksize}-${iodepth}-${th}.txt
cat << EOF > $config_folder/$fio_job_config
[global]
bs=${blocksize}
ioengine=$fio_engine
iodepth=$iodepth
size=$fio_size
direct=1
runtime=$fio_runtime
directory=$fio_directory
filename=$fio_filename

[$jobname]
rw=$mode
stonewall
EOF
	  nohup iostat -x 5 > $iostat_file &
          iostatPID=$!
	  nohup sh $top_monitor_sh $topstat_file $fio_runtime &
	  topstat_pid=$!
	  echo "-- iteration on ${ext_ip} ${server_ip} job${iter} testmode:${mode} iodepth:${iodepth} numjobs:${th} blocksize:${blocksize} --$(date +"%x %r %Z")" >> $LOGFILE
          log "fio $config_folder/$fio_job_config --group_reporting --output-format=json --numjobs=$th --output=$result_folder/$fio_output_file"
          fio_cmd="fio $config_folder/$fio_job_config --group_reporting --output-format=json --numjobs=$th --output=$result_folder/$fio_output_file"
	  echo "$fio_cmd" >> $LOGFILE
	  eval "$fio_cmd"
	  kill -0 $iostatPID
	  if [ $? -eq 0 ]
	  then
	     kill -9 $iostatPID
	  fi
	  kill -0 $topstat_pid
	  if [ $? -eq 0 ]
	  then
	     kill -s TERM $topstat_pid
	  fi
          iter=`expr $iter + 1`
		done
        done
    done
done
