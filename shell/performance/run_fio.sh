#!/bin/sh
run_fio() {
   local output_dir=$1
   local fio_common_options="$2"
   local fio_test_modes="$3"
   local fio_io_block_sizes="$4"
   local fio_numjobs_list="$5"
   local fio_iostat_prefix=$6
   local fio_prefix=$7
   local fio_log_file=$8

   local io
   local numjobs
   local iostat_file
   local jobname
   local iteration=1
   echo "para1: $output_dir"
   echo "para2: $fio_common_options"
   echo "para3: $fio_test_modes"
   echo "para4: $fio_io_block_sizes"
   echo "para5: $fio_numjobs_list"
   echo "para6: $fio_iostat_prefix"
   echo "para7: $fio_prefix"
   echo "para8: $fio_log_file"

   if [ ! -d $output_dir ]
   then
       mkdir $output_dir
   fi
   local LOGFILE=$output_dir/${fio_log_file}
   local server_ip
   local os=`uname`
   if [ "$os" == "FreeBSD" ]
   then
      server_ip=`ifconfig hn0 | grep "inet "|awk '{print $2}'`
   else
      if [ "$os" == "Linux" ]
      then
        server_ip=`ifconfig eth0 | grep "inet "|awk '{print $2}'`
      fi
   fi
   echo  "===================================== Starting Run $(date +"%x %r %Z") ================================" > $LOGFILE
   mount >> $LOGFILE
   echo "--- Disk Usage Before Generating New Files ---" >> $LOGFILE
   df -h >> $LOGFILE 
   fio --cpuclock-test >> $LOGFILE
   local os=`uname`
   if [ "$os" != "FreeBSD" ]
   then
      ## FreeBSD does not support this command
      fio_cmd="fio $fio_common_options --readwrite=read --bs=1M --runtime=1 --numjobs=8 --name=prepare"
      eval "$fio_cmd"
   fi
   echo "--- Disk Usage After Generating New Files ---" >> $LOGFILE
   df -h >> $LOGFILE
   echo "=== End Preparation  $(date +"%x %r %Z") ===" >> $LOGFILE

   for testmode in $fio_test_modes
   do
	for io in $fio_io_block_sizes
	do
		for numjobs in $fio_numjobs_list
		do
			iostat_file=$output_dir/${fio_iostat_prefix}-${testmode}-${io}K-${numjobs}.txt
			nohup iostat -x 5 > $iostat_file &
			iostatPID=$!
			echo "-- iteration ${iteration} ---${server_ip}, ${testmode}, ${io}K, ${numjobs} --$(date +"%x %r %Z")" >> $LOGFILE
			jobname=job${iteration}
			fio_cmd="fio $fio_common_options --readwrite=$testmode --bs=${io}K --numjobs=$numjobs --output=$output_dir/${fio_prefix}-${jobname}-${testmode}-${io}K-${numjobs}.json --name=${jobname}"
			echo "$fio_cmd" >> $LOGFILE
			eval "$fio_cmd"
			kill -9 $iostatPID
			let iteration=$iteration+1 > /dev/null
		done
	done
   done
}

if [ $# -ne 8 ]
then
   echo "Specify output_dir fio_common_options fio_test_modes fio_io_block_size_list fio_numjobs_list fio_iostat_prefix fio_prefix log_file"
   exit 1
fi

output_dir=$1
fio_common_options="$2"
fio_test_modes="$3"
fio_io_block_sizes="$4"
fio_numjobs_lists=$5
fio_iostat_prefix=$6
fio_prefix=$7
fio_log_file=$8

run_fio $output_dir "$fio_common_options" "$fio_test_modes" "$fio_io_block_sizes" "$fio_numjobs_lists" $fio_iostat_prefix $fio_prefix $fio_log_file
