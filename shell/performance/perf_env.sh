#!/bin/sh
base=$(dirname $0)
. ${base}/server_env.sh
set_perf_env()
{
if [ "$__PERF_ENV__" == "1" ]
then
   log "already included perf_env.sh"
   return
fi
__PERF_ENV__=1
##### storage performance #####
disk_dev_name=/dev/${disk_part}
mount_target=/mnt/datadrive
## storage
storage_result_folder_postfix=_result
storage_raw_folder_postfix=_raw
## sysbench
## sysbench fileio's fast mode is async, but it requires LIBAIO which is only available on Linux. So, we have to use sync mode which is the default configure.
## sysbench also does not support O_DIRECT which means it write/read file system.
auto_create_part_4_sysbench="true"
sysbench_runtime=300
sysbench_common_options="--test=fileio --file-total-size=120G --file-fsync-freq=0 --max-requests=0 --max-time=$sysbench_runtime"
sysbench_thread_list="1 8"
sysbench_modes="rndrd rndwr rndrw seqrd seqwr seqrewr"
sysbench_block_size_list="4 8"
sysbench_prefix=sysbench
sysbench_html=${sysbench_prefix}.html
sysbench_log_file=${sysbench_prefix}_log.txt
sysbench_iostat_prefix=iostat${sysbench_prefix}
sysbench_topstat_prefix=top${sysbench_prefix}
sysbench_io_runner=${base}/run_${sysbench_prefix}.sh
sysbench_html=${sysbench_prefix}.html
sysbench_result_folder=${sysbench_prefix}${storage_result_folder_postfix}
sysbench_raw_folder=${sysbench_prefix}${storage_raw_folder_postfix}
## fio on 120G device, no buffer(direct=1), runtime is 5min (runtime=300)
fio_disk_size=100G
fio_ioengine=posixaio
fio_iodepth_list="1 16 32 64 128"
fio_runtime=300
fio_common_options="--size=${fio_disk_size} --direct=1 --ioengine=${fio_ioengine} --filename=$disk_dev_name --overwrite=1 --iodepth=128 --runtime=${fio_runtime} --output-format=json"
fio_numjobs_list="1 8"
fio_block_size_list="4 8"
fio_modes="write read randread randwrite"
fio_prefix=fio
fio_iostat_prefix=iostat${fio_prefix}
fio_topstat_prefix=top${fio_prefix}
fio_jobname_prefix=iteration
fio_parser=${base}/fio-parse-json.py
fio_html=${fio_prefix}.html
fio_log_file=${fio_prefix}_log.txt
fio_runner=${base}/run_${fio_prefix}.sh
fio_jobs_runner=${base}/run_${fio_prefix}_jobs.sh 
fio_result_folder=${fio_prefix}${storage_result_folder_postfix}
fio_raw_folder=${fio_prefix}${storage_raw_folder_postfix}
## sio
sio_runner=run_sio.sh
sio_prefix=sio
sio_iostat_prefix=iostat${sio_prefix}
sio_topstat_prefix=top${sio_prefix}
sio_block_size_list="4k 8k 16k"
sio_thread_list="1 8"
sio_disk_size=5g
sio_runtime=120
sio_pkg=sio.tgz
sio_log_file=${sio_prefix}_log.txt
sio_html=${sio_prefix}.html
## start iperf3 on perf04 VM
## global variables to run performance test
## Summary comparison standard
## compare dst and src for the given aspect. 
## e.g. "Avg <= > 5" means if dst[Avg] <= src[Avg] && (src[Avg]/dst[Avg]-1)*100 > 5, then mark dst[Avg] as red background
red_config="Avg(Gbps) <= > 8:Stddev(Mbps) > > 8"
green_config="Avg(Gbps) > > 8:Stddev(Mbps) <= > 8"
sio_red_config="seqr <= > 8:seqw <= > 8:ranr <= > 8:ranw <= > 8:seqranrw <= > 8"
sio_green_config="seqr > > 8:seqw > > 8:ranr > > 8:ranw > > 8:seqranrw > > 8"
fio_red_config="randread <= > 8:randwrite <= > 8:read <= > 8:write <= > 8"
fio_green_config="randread > > 8:randwrite > > 8:read > > 8:write > > 8"
sysbench_red_config="rndrd <= > 8:rndrw <= > 8:seqrd <= > 8:seqrewr <= > 8"
sysbench_green_config="rndrd > > 8:rndrw > > 8:seqrd > > 8:seqrewr > > 8"
##
status_dir=status
## items in status directory
start_time=start_time.txt ## should be override in running context
end_time=end_time.txt     ## should be override
state_file=state.txt           ## running
ifstat_minval=0        ## minimum value is 1M (1000K)
ifstat_maxval=40000000    ## maximum value is 40G (40000000K)
### kernel parameters
#sysctl_option_list="dev.hn.?.lro_length_lim=18000"
sysctl_option_list="kern.ipc.soacceptqueue=1024"
####
src_folder=/usr/home/honzhan/head
kernel_bak_folder=kernel
kernel_zip_file=kernel.tgz

scsi_disk_info=""
perf04_cpu_core=""
perf04_cpu_info=""
perf04_uname=""
perf04_mem=""

perf03_cpu_core=""
perf03_cpu_info=""
perf03_uname=""
perf03_mem=""

duration=600
warm_dur=20
kq_netperf_pkg=${base}/kq_netperf.tgz
kq_netperf=kq_netperf
kq_netperf_srv=kq_recvserv
kq_netperf_sh=${base}/run_kq_netperf.sh
kq_netperf_prefix=kqperf
kq_netperf_html_desc="KQ Mutliple Thread sender/receiver between ${perf04_corp_ip}:${perf04_corp_port} and ${perf03_corp_ip}:${perf03_corp_port}"
netperf_html_desc="TCPStream(netperf) performance between ${perf04_corp_ip}:${perf04_corp_port} and ${perf03_corp_ip}:${perf03_corp_port}"
iperf_html_desc="iperf performance between ${perf04_corp_ip}:${perf04_corp_port} and ${perf03_corp_ip}:${perf03_corp_port}"
ntttcp_html_desc="NTTTCP-for-Linux performance between ${perf04_corp_ip}:${perf04_corp_port} and ${perf03_corp_ip}:${perf03_corp_port}"
tcpstream_pkg=${base}/tcp_stream.tbz
tcpstream=tcp_stream
config_ip_sh=${base}/config_ip.sh
netperf_sh=${base}/run_netperf.sh
top_monitor_sh=collect_top.sh
netdrv_wrapper_sh=netdrv_wrapper.sh
ssh_id_path=~/.ssh/id_rsa

result_path=~/NginxRoot/Perf
result_dir=`date +%Y%m%d%H%M%S`
iperf_server_port_start=21000
iperf_client_max_conn=64
iperf_server_port_serie_len=100
iperf_prefix=iperf
iperf_postfix=result.txt
iperf_sh=${base}/run_iperf.sh
netperf_prefix=netperf
ifstat_postfix=ifstat
top_postfix=top

ntttcp_prefix=ntttcp
netperf_marker=n
kq_netperf_marker=k
iperf_marker=i
ntttcp_marker=nt
csv_chart_file_postfix=_chart.csv
csv_table_file_postfix=_table.csv
#sysbench_csv_table_postfix=_sysbench_table.csv
#fio_csv_table_postfix=_fio_table.csv
bs_postfix_bar="bs_bar"
bs_postfix_table="bs_tbl"
bs_lat_postfix_bar="bs_lat_bar"
bs_lat_postfix_table="bs_lat_tbl"
## network mapper table from marker to prefix
marker_list="$netperf_marker|$kq_netperf_marker|$iperf_marker|$ntttcp_marker"
marker_to_prefix="${netperf_marker}:${netperf_prefix}|${kq_netperf_marker}:${kq_netperf_prefix}|${iperf_marker}:${iperf_prefix}|${ntttcp_marker}:${ntttcp_prefix}"
marker_list_sep="|"
marker_to_prefix_sep=":"

marker_to_htmldesc="${netperf_marker}::${netperf_html_desc}|${kq_netperf_marker}::${kq_netperf_html_desc}|${iperf_marker}::${iperf_html_desc}|${ntttcp_marker}::${ntttcp_html_desc}"
marker_to_htmldesc_sep="::"

drv_list="$netperf_prefix|$kq_netperf_prefix|$iperf_prefix|$fio_prefix|$sysbench_prefix|$ntttcp_prefix|$sio_prefix" ## enabled all drivers
drv_list_sep="|"
drv_config_folder="config"
## storage prefix table
storage_prefix_list="$fio_prefix|$sysbench_prefix|$sio_prefix"
storage_prefix_sep="|"
## global variables to format data and generate html
data_file="perf_concat_result.data"
end_file="perf_last_column.data"
final_output_file=perf_trend.html
table_data_file="perf_table_result.data"

web_protocol=http
webserver_port=80
## temporary directory
tmp_dir=tmp
## html generation
css_folder=${base}/html_tmpl/css
html_header_tmpl=${base}/html_tmpl/header.tmpl
summary_html_file=summary.html
## email
subject_prefix="Performance Report "
}

set_perf_env

## utility functions

## given "fio" and "_red_config"
## return the value of $fio_red_config defined in perf_env.sh
derefer_2vars() {
   local prefix=$1
   local postfix=$2
   local v=${prefix}${postfix}
   eval echo \$${v}
}
## Bourne shell does not support array, so a string is used
## to work around with the hep of awk array

## return the value according to index: 
## @param arr: array (using string)
## @param index: array index (start from 1)
## @param separator: string's separator which is used separate the array item
array_get() {
  local arr=$1
  local index=$2
  local separator=$3
  echo ""|awk -v sep=$separator -v str="$arr" -v idx=$index '{
   split(str, array, sep);
   print array[idx]
}'
}

## return the value according to key
## @param arr: array (using string)
## @param key: key value (string)
## @param arr_item_sep: string's separator which is used separate the array item
## @param item_key_value_sep: key-value separator
array_getvalue() {
  local arr=$1
  local key=$2
  local arr_item_sep=$3
  local item_key_value_sep=$4
  echo ""|awk -v sep="$arr_item_sep" -v str="$arr" -v item_sep="$item_key_value_sep" -v k="$key" '{
    split(str, array, sep);
    for(m=1; m <=length(array); m++) {
       split(array[m], item, item_sep);
       if (item[1] == k) {
          print item[2];
          break;
       }
    }
}'
}

## return the length of the array
## @param arr: array (using string)
## @param separator: string's separator which is used separate the array item
array_len() {
  local arr=$1
  local separator=$2
  echo ""|awk -v sep=$separator -v str="$arr" '{
   split(str, array, sep);
   print length(array)
}'
}

log_level=1
log()
{
   local msg="$1"
   log_tag="PERF_TEST"
   if [ $log_level -ge 2 ]
   then
      logger -t $log_tag "$msg"
   fi
}

create_tmp_dir_ifnotexist()
{
   if [ ! -d $tmp_dir ]
   then
      mkdir $tmp_dir
   fi
}

create_kernel_bak_ifnotexist()
{
   if [ ! -d $kernel_bak_folder ]
   then
      mkdir $kernel_bak_folder
   fi
}

rm_tmp_dir_ifexist()
{
   if [ -d $tmp_dir ]
   then
      rm -rf $tmp_dir
   fi
}

get_tunable_option()
{
	local ip=$1
	local port=$2
	local tunable=""
	local os=`ssh test@${ip} -p $port uname`
	if [ "$os" == "FreeBSD" ]
	then
	  tunable=`ssh test@${ip} -p $port cat /boot/loader.conf`
	fi
	echo "${tunable}"
}

get_hn_internal_no()
{
	local corp_ip=$1
	local corp_port=$2
	local inter_ip=$3
	local i=""
	local f=""
	local track_if=""
	local if_list=`ssh test@${corp_ip} -p ${corp_port} ifconfig -l`
	for i in $if_list
	do
		f=`ssh test@${corp_ip} -p ${corp_port} ifconfig $i|sed -n "/$inter_ip/p"`
		if [ "$f" != "" ]
		then
			track_if=$i	
			break
		fi
	done
	echo $track_if|grep -o '[0-9]\+'
}

## Generally describe the comparison
explain_green_config_general()
{
	local config="$1"
	local rtn=`echo ""|awk -v c="$config" '
	BEGIN{
	    desc="";
	    split(c, config_list, ":");
	    for (i=1; i <= length(config_list); i++) {
		split(config_list[i], config_item, " ");
		desc=desc"<li>For <b>" config_item[1]"</b>";
		
		if (config_item[2] == ">") {
			desc=desc", the bigger the better."
		} else if (config_item[2] == "<=") {
			desc=desc", the smaller the better."
		}
		desc=desc"</li>\n"
	    }
	}
	{
	    
	}
	END{print desc}'`
	echo "$rtn"
}
##
explain_green_config_detail()
{
	local config="$1"
	local rtn=`echo ""|awk -v c="$config" '
	BEGIN{
	    desc="";
	    split(c, config_list, ":");
	    for (i=1; i <= length(config_list); i++) {
		split(config_list[i], config_item, " ");
		desc=desc"<li>If the improvement of <b>" config_item[1]"</b>";
		
		if (config_item[3] == ">") {
			desc=desc" is bigger than"
		} else if (config_item[3] == "<=") {
			desc=desc" is smaller than"
		}
		desc=desc" "config_item[4]"%, it is marked as <font color='green'>green</font></li>\n"
	    }
	}
	{
	    
	}
	END{print desc}'`
	echo "$rtn"
}

##
explain_red_config_detail()
{
	local config="$1"
	local rtn=`echo ""|awk -v c="$config" '
	BEGIN{
	    desc="";
	    split(c, config_list, ":");
	    for (i=1; i <= length(config_list); i++) {
		split(config_list[i], config_item, " ");
		desc=desc"<li>If the drop of <b>" config_item[1] "</b>";
		
		if (config_item[3] == ">") {
			desc=desc" is bigger than"
		} else if (config_item[3] == "<=") {
			desc=desc" is smaller than"
		}
		desc=desc" "config_item[4]"%, it is marked as <font color='red'>red</font></li>\n"
	    }
	}
	{
	    
	}
	END{print desc}'`
	echo "$rtn"
}
## replace the "?" in pattern and return the replaced value
replace_question_mark()
{
	local pattern=$1
	local text=$2
	echo "$pattern"|sed -e "s/?/$text/g"
}

## for a given sysctl name, return its value
## e.g. "dev.hn.0.lro_length_lim: 18000"
get_sysctl_option()
{
	local corp_ip=$1
	local corp_port=$2
	local sysctl_name=$3
	local value=`ssh test@${corp_ip} -p $corp_port sysctl $sysctl_name`
	echo "$value"
}

get_sysctl_option_list_values()
{
	local corp_ip=$1
	local corp_port=$2
	local inter_ip=$3
	local sysctl_name=""
	local sysctl_value=""
	local sysctl_values=""
	local os=`ssh test@$corp_ip -p $corp_port uname`
	if [ "$os" == "FreeBSD" ]
	then
		local if_interface=$(get_hn_internal_no $corp_ip $corp_port $inter_ip)
		for i in $sysctl_option_list
		do
			sysctl_name=`echo "$i"|awk -F = '{print $1}'`
			sysctl_name=$(replace_question_mark $sysctl_name $if_interface)
			sysctl_value=$(get_sysctl_option $corp_ip $corp_port $sysctl_name)
			sysctl_values=${sysctl_values}" ${sysctl_value}"
		done
	fi
	echo "$sysctl_values"
}

get_cpu_core()
{
  local remote_ip=$1
  local remote_port=$2
  local os_name=`ssh test@$remote_ip -p $remote_port uname`
  local cpu_core=""
  if [ "$os_name" == "FreeBSD" ]
  then
      cpu_core=`ssh test@$remote_ip -p $remote_port sysctl hw.ncpu | awk '{printf("%d\n",$2)}'`
  else
      if [ "$os_name" == "Linux" ]
      then
          cpu_core=`ssh test@$remote_ip -p $remote_port nproc`
      fi
  fi
  echo $cpu_core
}

os_para_config()
{
	local perf03_os=`ssh test@${perf03_corp_ip} -p ${perf03_corp_port} uname`
	local perf04_os=`ssh test@${perf04_corp_ip} -p ${perf04_corp_port} uname`
	if [ "$perf03_os" == "FreeBSD" ] && [ "$perf04_os" == "FreeBSD" ]
	then
		local perf03_hn_no=$(get_hn_internal_no ${perf03_corp_ip} ${perf03_corp_port} ${perf03_inter_ip})
		local perf04_hn_no=$(get_hn_internal_no ${perf04_corp_ip} ${perf04_corp_port} ${perf04_inter_ip})
		local perf03_normal=""
		local perf04_normal=""
		for i in $sysctl_option_list
		do
			log "replace_question_mark $i $perf03_hn_no"
			perf03_normal=$(replace_question_mark $i $perf03_hn_no)
			log "replace_question_mark $i $perf04_hn_no"
			perf04_normal=$(replace_question_mark $i $perf04_hn_no)
			ssh root@${perf03_corp_ip} -p ${perf03_corp_port} "sysctl $perf03_normal"
			log "ssh root@${perf03_corp_ip} -p ${perf03_corp_port} sysctl $perf03_normal"
			ssh root@${perf04_corp_ip} -p ${perf04_corp_port} "sysctl $perf04_normal"
			log "ssh root@${perf04_corp_ip} -p ${perf04_corp_port} sysctl $perf04_normal"
		done
	fi
}

check_runtime_env()
{
	perf03_cpu_core=$(get_cpu_core ${perf03_corp_ip} ${perf03_corp_port})
	perf03_cpu_info=`ssh test@${perf03_corp_ip} -p ${perf03_corp_port} dmesg | grep "Intel(R)"`
	perf03_uname=`ssh test@${perf03_corp_ip} -p ${perf03_corp_port} "uname -a"`
	perf03_mem=`ssh test@${perf03_corp_ip} -p ${perf03_corp_port} "dmesg|grep 'real memory'"|awk -F = '{print $2}'|head -n 1`
	perf04_cpu_core=$(get_cpu_core ${perf04_corp_ip} ${perf04_corp_port})
	perf04_cpu_info=`ssh test@${perf04_corp_ip} -p ${perf04_corp_port} dmesg | grep "Intel(R)"`
	perf04_uname=`ssh test@${perf04_corp_ip} -p ${perf04_corp_port} "uname -a"`
	perf04_mem=`ssh test@${perf04_corp_ip} -p ${perf04_corp_port} "dmesg|grep 'real memory'"|awk -F = '{print $2}'|head -n 1`
}

check_disk_info()
{
	local remote_ip=$1
	local remote_port=$2
	scsi_disk_info=`ssh test@${remote_ip} -p ${remote_port} egrep "^$disk_part" /var/run/dmesg.boot|sort|uniq`
}

create_status_dir_if_notexist()
{
	if [ ! -d $status_dir ]
	then
		mkdir $status_dir
	fi
}

create_start_timestamp()
{
	create_status_dir_if_notexist
	local d=`date`
	echo "$d" > $status_dir/$start_time
}

create_end_timestamp()
{
	create_status_dir_if_notexist
	local d=`date`
	echo "$d" > $status_dir/$end_time
}

output_state_msg()
{
	local msg=$1
	create_status_dir_if_notexist
	echo "$msg" > $status_dir/$state_file
	log "$msg"
}
#################### FIO #################
#################### sysbench ############
prepare_partition() {
    local remote_ip=$1
    local remote_port=$2
    local partition=$3
    create_tmp_dir_ifnotexist
    log "ssh root@${remote_ip} -p $remote_port gpart create -s GPT $partition"
    ssh root@${remote_ip} -p $remote_port "gpart create -s GPT $partition" > $tmp_dir/gpart_create_${remote_ip}.log
    log "ssh root@${remote_ip} -p $remote_port gpart add -t freebsd-ufs -a 256k $partition"
    ssh root@${remote_ip} -p $remote_port "gpart add -t freebsd-ufs -a 256k $partition" > $tmp_dir/gpart_add_${remote_ip}.log
    log "ssh root@${remote_ip} -p $remote_port newfs -U -b 8k $partition"
    ssh root@${remote_ip} -p $remote_port "newfs -U -b 8k $partition" > $tmp_dir/newfs_${remote_ip}.log
    log "ssh root@${remote_ip} -p $remote_port mkdir $mount_target"
    ssh root@${remote_ip} -p $remote_port "mkdir $mount_target" > $tmp_dir/mkdir_4_mount_${remote_ip}.log
    log "ssh root@${remote_ip} -p $remote_port mount -o noatime $partition $mount_target"
    ssh root@${remote_ip} -p $remote_port "mount -o noatime $partition $mount_target" > $tmp_dir/mount_noatime_${remote_ip}.log
    ## check whether partition is ready
    part=`ssh root@${remote_ip} -p $remote_port mount|grep "$partition"`
    if [ "$part" != "" ]
    then
       echo 0
    else
       echo 1
    fi
}

recover_gpt_if() {
    local remote_ip=$1
    local remote_port=$2
    local gpart_recover
    local ret_value

    create_tmp_dir_ifnotexist
    ## check whether disk existed
    ssh root@${remote_ip} -p ${remote_port} "diskinfo $disk_dev_name" > $tmp_dir/diskinfo_${remote_ip}.log
    if [ $? -ne 0 ]
    then
	log "Disk '$disk_dev_name' does not exist!"
        echo 1
	return 
    fi
    ssh root@${remote_ip} -p ${remote_port} "gpart show $disk_dev_name" > $tmp_dir/gpart_show_${remote_ip}.log
    ret_value=$?
    if [ $ret_value -ne 0 ]
    then
       ssh root@${remote_ip} -p ${remote_port} gpart create -s GPT $disk_dev_name > $tmp_dir/gpart_create_${remote_ip}.log
       if [ $? -eq 0 ]
       then
          log "gpart successfully create partition"
       else
          log "gpart failed to create partition"
          echo 1
	  return
       fi
    fi
    gpart_recover=`ssh root@${remote_ip} -p ${remote_port} gpart recover $disk_dev_name`
    log "$gpart_recover"
    echo 0
}

mount_dev_if_not_mounted() {
    local remote_ip=$1
    local remote_port=$2
    local dev=`ssh root@${remote_ip} -p $remote_port df -h|tail -n 1|awk '{print $1}'`
    create_tmp_dir_ifnotexist
    #echo $dev
    if [ $dev != $disk_dev_name ]
    then
        log "Need to mount $disk_dev_name to $mount_target"
	ssh root@${remote_ip} -p ${remote_port} mount -o noatime $disk_dev_name $mount_target > $tmp_dir/mount_${remote_ip}.log
	if [ $? -ne 0 ]
	then
	    log "Error occurs for mount $disk_dev_name to $mount_target on ${remote_ip}"
	    echo 1
	else
	    log "Successfully mount $disk_dev_name to $mount_target on ${remote_ip}"
	    echo 0
	fi
    else 
        log "$disk_dev_name has already been mounted to $mount_target on ${remote_ip}"
	echo 0
    fi
}

setup_device_fs() {
    local remote_ip=$1
    local remote_port=$2
    local gpart
    local mounted=$(mount_dev_if_not_mounted $remote_ip $remote_port)
    if [ $mounted -ne 0 ]
    then
        gpart=$(recover_gpt_if $remote_ip $remote_port)
	if [ $gpart -ne 0 ]
	then
	   echo 1
	fi
    fi   
    echo 0
}

run_fio() {
    local output_dir=${fio_prefix}_`date +%Y%m%d%H%M%S`
    local remote_ip=$1
    local remote_port=$2
    local out=$3
    local device=$4
    scp -P $remote_port $fio_runner test@${remote_ip}:~
    part=`ssh root@${remote_ip} -p $remote_port mount|grep "$device"`
    if [ "$part" != "" ]
    then
	ssh root@${remote_ip} -p $remote_port umount $mount_target
    fi
    log "ssh root@${remote_ip} -p $remote_port \"cd /home/test; sh $fio_runner $output_dir \"$fio_common_options\" \"$fio_modes\" \"$fio_block_size_list\" \"$fio_numjobs_list\" $fio_iostat_prefix $fio_prefix $fio_log_file\""
    ssh root@${remote_ip} -p $remote_port "cd /home/test; sh $fio_runner $output_dir \"$fio_common_options\" \"$fio_modes\" \"$fio_block_size_list\" \"$fio_numjobs_list\" $fio_iostat_prefix $fio_prefix $fio_log_file"
    scp -P $remote_port root@${remote_ip}:/home/test/$output_dir/* ${out}/
}

run_sio() {
    local remote_ip=$1
    local remote_port=$2
    local out=$3
    local sio_file=$4
    local os=`ssh test@$remote_ip -p $remote_port uname`
    local sio_drv
    local output_dir=${sio_prefix}_`date +%Y%m%d%H%M%S`
    local sio_env_file=sio_env.sh
    if [ "$os" == "FreeBSD" ]
    then
        sio_drv=sio/sio_ntap_freebsd
    else
        if [ "$os" == "Linux" ]
        then
            sio_drv=sio/sio_ntap_linux
        fi
    fi
cat << EOF > $sio_env_file
sio_server_ip=$remote_ip
sio_server_port=$remote_port
sio_block_size_list="$sio_block_size_list"
sio_thread_list="$sio_thread_list"
sio_size=$sio_disk_size
sio_runtime=$sio_runtime
sio_filename=${sio_file}
sio_drv=${sio_drv}
sio_seqw="0 0"
sio_seqr="100 0"
sio_ranr="100 100"
sio_ranw="0 100"
sio_seqranrw="50 50"
sio_modes="seqw seqr ranr ranw seqranrw"
sio_iostat_prefix=${sio_iostat_prefix}
sio_topstat_prefix=${sio_topstat_prefix}
sio_log_file=${sio_log_file}
top_monitor_sh=${top_monitor_sh}
EOF
    scp -P $remote_port $top_monitor_sh test@${remote_ip}:~/
    scp -P $remote_port $sio_pkg test@${remote_ip}:~/
    ssh test@${remote_ip} -p $remote_port "tar zxvf $sio_pkg;cd sio; sh build.sh"
    scp -P $remote_port $sio_runner test@${remote_ip}:~/
    scp -P $remote_port ./$sio_env_file test@${remote_ip}:~/
    part=`ssh root@${remote_ip} -p $remote_port mount|grep "$sio_file"`
    if [ "$part" != "" ]
    then
	ssh root@${remote_ip} -p $remote_port umount $mount_target
    fi
    log "ssh root@${remote_ip} -p $remote_port \"cd /home/test; sh $sio_runner $output_dir $sio_env_file\""
    ssh root@${remote_ip} -p $remote_port "cd /home/test; sh $sio_runner $output_dir $sio_env_file"
    scp -r -P $remote_port "root@${remote_ip}:/home/test/$output_dir/*" ${out}/
}

run_fio_jobs() {
    local remote_ip=$1
    local remote_port=$2
    local out=$3
    local fio_file=$4
    local fio_ioengine=$5
    local output_dir=${fio_prefix}_`date +%Y%m%d%H%M%S`
    local fio_env_file=fio_env.sh
cat << EOF > $fio_env_file
fio_block_size_list="$fio_block_size_list"
fio_numjobs_list="$fio_numjobs_list"
fio_engine=$fio_ioengine
fio_iodepth_list="$fio_iodepth_list"
fio_size=$fio_disk_size
fio_runtime=$fio_runtime
fio_directory=/dev/
fio_filename=${fio_file}
fio_modes="${fio_modes}"
fio_iostat_prefix=${fio_iostat_prefix}
fio_log_file=${fio_log_file}
top_monitor_sh=${top_monitor_sh}
fio_topstat_prefix=${fio_topstat_prefix}
EOF
    local os=`ssh test@$remote_ip -p $remote_port uname`
    if [ "$os" == "FreeBSD" ]
    then
       log "ssh root@${remote_ip} -p $remote_port freebsd-version"
       local freebsd_version=`ssh root@${remote_ip} -p $remote_port freebsd-version`
       if [ "$freebsd_version" == "10.3-RELEASE" ]
       then
	  ## For 10.3 we have to manually load aio module
	  log "ssh root@${remote_ip} -p $remote_port kldload aio"
	  ssh root@${remote_ip} -p $remote_port "kldload aio"
       fi
    fi
    scp -P $remote_port $top_monitor_sh test@${remote_ip}:~/
    scp -P $remote_port $fio_jobs_runner test@${remote_ip}:~/
    scp -P $remote_port ./$fio_env_file test@${remote_ip}:~/
    part=`ssh root@${remote_ip} -p $remote_port mount|grep "$fio_file"`
    if [ "$part" != "" ]
    then
	ssh root@${remote_ip} -p $remote_port umount $mount_target
    fi
    log "ssh root@${remote_ip} -p $remote_port \"cd /home/test; sh $fio_jobs_runner $output_dir $fio_env_file\""
    ssh root@${remote_ip} -p $remote_port "cd /home/test; sh $fio_jobs_runner $output_dir $fio_env_file"
    scp -r -P $remote_port "root@${remote_ip}:/home/test/$output_dir/*" ${out}/
}

run_sysbench() {
    local output_dir=sysbench_`date +%Y%m%d%H%M%S`
    local remote_ip=$1
    local remote_port=$2
    local out=$3
    local partition=$4
    local auto_part=$5
    local os=`ssh test@$remote_ip -p $remote_port uname`
    if [ "$os" == "FreeBSD" ] && [ "$auto_part" == "true" ]
    then
       local is_ready=$(prepare_partition $remote_ip $remote_port $partition)
       if [ $is_ready == 1 ]
       then
          log "The partition is not ready for sysbench, so ignore the sysbench running"
          echo 1
          return
       fi
    fi
    local env_script="sysbench_env.sh"
cat << EOF > $env_script
sysbench_remote_ip=$remote_ip
sysbench_remote_port=$remote_port
sysbench_runtime=$sysbench_runtime
sysbench_common_options="$sysbench_common_options"
sysbench_modes="$sysbench_modes"
sysbench_thread_list="$sysbench_thread_list"
sysbench_block_size_list="$sysbench_block_size_list"
working_dir=$mount_target
iostat_prefix=$sysbench_iostat_prefix
sysbench_topstat_prefix=${sysbench_topstat_prefix}
sysbench_log_file=$sysbench_log_file
top_monitor_sh=${top_monitor_sh}
EOF
    scp -P $remote_port $top_monitor_sh test@${remote_ip}:~/
    scp -P $remote_port $env_script test@${remote_ip}:~
    scp -P $remote_port $sysbench_io_runner test@${remote_ip}:~
    log "ssh root@${remote_ip} -p $remote_port cd /home/test; sh $sysbench_io_runner $output_dir $env_script"
    ssh root@${remote_ip} -p $remote_port "cd /home/test; sh $sysbench_io_runner $output_dir $env_script"
    scp -P $remote_port root@${remote_ip}:$mount_target/$output_dir/* ${out}/
}

get_folder_from_path()
{
   local input_path=$1
   local len=`echo ""|awk -v a=$input_path '{printf("%d\n", length(a))}'`
   local slash=`echo $input_path|cut -c $len`
   if [ $slash == "/" ]
   then
      len=`expr $len - 1`
      input_path=`echo $input_path|cut -c -$len`
   fi
   input_path=${input_path##*/}
   echo $input_path
}

gen_bar_tbl_data_4_storage() {
  local tmp_file=$1
  local output_dir=$2
  local gen_title=$3
  local bs_file_postfix=$4
  local marker=$5  ## distinguish the tmp file for different calling purpose, e.g. fio or sysbench
  local mode_list=""
  local thread_list=""
  local iodepth_list=""
  local bs_tmp_file=""
  local output_file=""
  local raw_file=""
  local i
  local m
  local j
  ## find mode list
  for i in `awk -F / '{print $2}' $tmp_file| sort| uniq`
  do
     mode_list=${mode_list}" $i"
  done
  ## find thread list
  for i in `awk -F / '{print $4}' $tmp_file| sort -n | uniq`
  do
     thread_list=${thread_list}" $i"
  done
  ## find iodepth list
  for i in `awk -F / '{print $3}' $tmp_file| sort -n | uniq`
  do
     iodepth_list=${iodepth_list}" $i"
  done
  ## iterate each bs size
  for i in `awk -F / '{print $1}' $tmp_file| sort| uniq`
  do
     bs_tmp_file=$output_dir/${i}_bs_${marker}_raw.txt
     grep "^${i}" $tmp_file > $bs_tmp_file
  done

   if [ "$gen_title" == "1" ]
   then
     for j in `awk -F / '{print $1}' $tmp_file| sort| uniq`
     do
	for i in ${thread_list}
	do
          output_file=$output_dir/${j}_${i}_${bs_file_postfix}
          echo -n "['IOdepth'" >> $output_file
          for i in ${mode_list}
          do
            echo -n ",'$i'" >> $output_file
          done
          echo "]," >> $output_file
	done
     done
   fi
   for k in `awk -F / '{print $1}' $tmp_file| sort| uniq`
   do
     for i in ${thread_list}
     do
        output_file=$output_dir/${k}_${i}_${bs_file_postfix}
        raw_file=$output_dir/${k}_bs_${marker}_raw.txt
        for m in ${iodepth_list}
        do
           echo -n "['$m'" >> $output_file
           for j in `grep "/$m/$i/" $raw_file|sort -t / -k 2|awk -F / '{print $NF}'`
           do
             echo -n ",$j" >> $output_file
           done
           echo "]," >> $output_file
	done
     done
   done
}

## generate the html file for storage raw data and temp result
## @param1: temp file with format: BS/MODE/IODEPTH/THREAD/IOPS in each line
## @param2: storage prefix, e.g. "fio" or "sysbench"
## @param3: result directory
## @param4: raw data directory
## @param5: remote server ip
## @param6: remote server port
gen_html_file_4_storage() {
  local storage_raw_data_file=$1
  local storage_prefix=$2
  local final_html_file_name=$(derefer_2vars $storage_prefix "_html")
  local output_dir=$3
  local input_dir=$4
  local remote_ip=$5
  local remote_port=$6
  local gen_latency=$7
  local raw_folder=$(get_folder_from_path $input_dir)
  local result_folder=$(get_folder_from_path $output_dir)

  local storage_category=$storage_prefix
  local log_file=$(derefer_2vars $storage_prefix "_log_file")
  local stat_prefix=$(derefer_2vars $storage_prefix "_iostat_prefix")
  local raw_data_csv_postfix=_${storage_prefix}${csv_table_file_postfix} #$(derefer_2vars $storage_prefix "_csv_table_postfix")
  local topstat_prefix=$(derefer_2vars $storage_prefix "_topstat_prefix")
  local tmp_file=$storage_raw_data_file
  local bs_list=""
  local mode_list=""
  local thread_list=""
  local cpu_core=""
  local uname_all=`ssh test@$remote_ip -p $remote_port uname -a`
  local test_start_time=`cat $status_dir/$start_time`
  local test_end_time=`cat $status_dir/$end_time`
  local csv_postfix="normal_csv"
  local normal_csv_file
  local i
  local j
  local m
  local k
  cpu_core=$(get_cpu_core $remote_ip $remote_port)
  ## generate block size list
  for i in `awk -F / '{print $1}' $tmp_file| sort| uniq`
  do
     bs_list=${bs_list}" "${i}
  done
  ## generate mode list
  for i in `awk -F / '{print $2}' $tmp_file| sort| uniq`
  do
     mode_list=${mode_list}" $i"
  done
  ## generate thread list
  for i in `awk -F / '{print $4}' $tmp_file| sort| uniq`
  do
     thread_list=${thread_list}" $i"
  done

  ## generate the html file
  cat $html_header_tmpl > $final_html_file_name
cat << _EOF >> $final_html_file_name
    <script type="text/javascript">
      google.charts.load('current', {'packages':['bar', 'table']});
_EOF

  for i in $bs_list
  do
    for j in $thread_list
    do
cat << _EOF >> $final_html_file_name
      google.charts.setOnLoadCallback(drawChart_${i}_${j});
      google.charts.setOnLoadCallback(drawTable_${i}_${j});
_EOF
      if [ "$gen_latency" == "1" ]
      then
cat << _EOF >> $final_html_file_name
      google.charts.setOnLoadCallback(drawChart_${i}_${j}_lat);
      google.charts.setOnLoadCallback(drawTable_${i}_${j}_lat);
_EOF
      fi
    done
  done

  ## draw chart
  for i in $bs_list
  do
    for j in $thread_list
    do
cat << EOF >> $final_html_file_name
      function drawChart_${i}_${j}() {
	var data = google.visualization.arrayToDataTable([
EOF
    cat ${output_dir}/${i}_${j}_$bs_postfix_bar >> $final_html_file_name
cat << EOF >> $final_html_file_name
	]);
        var options = {
          chart: {
            title: '$storage_category Performance (IOPS) with blocksize ${i}',
            subtitle: 'Storage Perf Test on $os VM ${remote_ip}:${remote_port}',
          }
        };

        var chart = new google.charts.Bar(document.getElementById('${i}_${j}_chart'));

        chart.draw(data, options);
      }
EOF
      if [ "$gen_latency" == "1" ]
      then
cat << EOF >> $final_html_file_name
      function drawChart_${i}_${j}_lat() {
	var data = google.visualization.arrayToDataTable([
EOF
    cat ${output_dir}/${i}_${j}_$bs_lat_postfix_bar >> $final_html_file_name
cat << EOF >> $final_html_file_name
	]);
        var options = {
          chart: {
            title: '$storage_category Performance (latency) with blocksize ${i}',
            subtitle: 'Storage Perf Test on $os VM ${remote_ip}:${remote_port}',
          }
        };

        var chart = new google.charts.Bar(document.getElementById('${i}_${j}_lat_chart'));

        chart.draw(data, options);
      }
EOF
      fi
    done
  done

  ## draw table
  for i in $bs_list
  do
     for k in $thread_list
     do
cat << EOF >> $final_html_file_name
      function drawTable_${i}_${k}() {
	var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
	var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
	var data = new google.visualization.DataTable();
	data.addColumn('string', 'IOdepth');
EOF
	for j in $mode_list
	do
cat << EOF >> $final_html_file_name
	data.addColumn('number', '$j');
EOF
	done

cat << EOF >> $final_html_file_name
	data.addRows([
EOF
	cat ${output_dir}/${i}_${k}_$bs_postfix_table >> $final_html_file_name
	## generate normalized csv file:
	normal_csv_file=${output_dir}/${i}_${k}_${bs_postfix_table}_${csv_postfix}
	echo -n "IOdepth," >> $normal_csv_file
        for j in $mode_list
	do
	   echo -n "${j}," >> $normal_csv_file
	done
	echo "" >> $normal_csv_file
	sed -e 's/\[//g' -e 's/\]//g' -e 's/,$//g' ${output_dir}/${i}_${k}_$bs_postfix_table >> $normal_csv_file
cat << EOF >> $final_html_file_name
	]);
        var table = new google.visualization.Table(document.getElementById('${i}_${k}_table'));
	table.draw(data, options);
      }
EOF
      ## for latency data
      if [ "$gen_latency" == "1" ]
      then
cat << EOF >> $final_html_file_name
      function drawTable_${i}_${k}_lat() {
	var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
	var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
	var data = new google.visualization.DataTable();
	data.addColumn('string', 'IOdepth');
EOF
	for j in $mode_list
	do
cat << EOF >> $final_html_file_name
	data.addColumn('number', '$j');
EOF
	done

cat << EOF >> $final_html_file_name
	data.addRows([
EOF
	cat ${output_dir}/${i}_${k}_${bs_lat_postfix_table} >> $final_html_file_name

	## generate normalized csv file:
	normal_csv_file=${output_dir}/${i}_${k}_${bs_lat_postfix_table}_${csv_postfix}
	echo -n "IOdepth," >> $normal_csv_file
        for j in $mode_list
	do
	   echo -n "${j}," >> $normal_csv_file
	done
	echo "" >> $normal_csv_file
	sed -e 's/\[//g' -e 's/\]//g' -e 's/,$//g' ${output_dir}/${i}_${k}_${bs_lat_postfix_table} >> $normal_csv_file
cat << EOF >> $final_html_file_name
	]);
        var table = new google.visualization.Table(document.getElementById('${i}_${k}_lat_table'));
	table.draw(data, options);
      }
EOF
      fi
    done
  done

  local tunable_option=$(get_tunable_option ${remote_ip} ${remote_port})
cat << EOF >> $final_html_file_name
  </script>
</head>
<body>
  <div class="container">
        <header>
            <h1>Storage Performance Report</h1>
        </header>
        <div class="wrapper clearfix">
          <div class="content">
                <section>
                    <h2>Environment</h2>
		    <p>Time used for the whole run on ${remote_ip}:${remote_port}: from <b>"$test_start_time"</b> to <b>"$test_end_time"</b>.</p>
		    <b>Environment for ${remote_ip}:${remote_port}</b><br>
		    <ul>
			<li>CPU: $cpu_core</li>
			<li>OS: "$uname_all"</li>
			<li>Tunable: "$tunable_option"</li>
		    </ul>
		</section>
	  </div>
	  <div class="content">
		<section>
		    <h2>Result</h2>
		    <b>Summary</b>
EOF
	if [ "$gen_latency" == "1" ]
	then
cat << EOF >> $final_html_file_name
		    <ul class="two-columns">
EOF
	else
cat << EOF >> $final_html_file_name
		    <ul>
EOF
	fi
  for i in $bs_list
  do
    for j in $thread_list
    do
      if [ "$gen_latency" == "1" ]
      then
cat << EOF >> $final_html_file_name
                        <li><a href="${result_folder}/${i}_${j}_${bs_postfix_table}_${csv_postfix}">block size: ${i}, thread: ${j}, IOPS</a><div id="${i}_${j}_table"></div></li>
			<li><a href="${result_folder}/${i}_${j}_${bs_lat_postfix_table}_${csv_postfix}">block size: ${i}, thread: ${j}, Latency</a><div id="${i}_${j}_lat_table"></div></li>
EOF
      else
cat << EOF >> $final_html_file_name
                        <li><b>block size: ${i}, thread: ${j}</b><a href="${result_folder}/${i}_${j}_${bs_postfix_table}_${csv_postfix}">IOPS</a><div id="${i}_${j}_table"></div></li>
EOF
      fi
    done
  done
cat << EOF >> $final_html_file_name
                    </ul>
		    <b>Charts</b>
		    <ul>
EOF
  for i in $bs_list
  do
    for j in $thread_list
    do
cat << EOF >> $final_html_file_name
			<li><b>block size: ${i}, thread: ${j}</b><div id="${i}_${j}_chart" style="width: 900px; height: 500px;"></div></li>
EOF
      if [ "$gen_latency" == "1" ]
      then
cat << EOF >> $final_html_file_name
			<li><b>block size: ${i}, thread: ${j}</b><div id="${i}_${j}_lat_chart" style="width: 900px; height: 500px;"></div></li>
EOF
      fi
    done
  done
cat << EOF >> $final_html_file_name
		    </ul>
		</section>
	   </div>
	   <div class="content">
                <section>
                    <h2>Logs and statistics</h2>
		    <div><a href="${raw_folder}/${log_file}">$storage_category log file (contains command options)</a></div>
EOF
  for i in `ls ${input_dir}/${stat_prefix}*`
  do
     io_statistic=${i##*/}
cat << EOF >> $final_html_file_name
		    <div><a href="${raw_folder}/${io_statistic}">${io_statistic}</a></div>
EOF
  done
######################################################
########## special handle for fio configuration ######
  for i in `ls ${input_dir}/*.config`
  do
     io_statistic=${i##*/}
cat << EOF >> $final_html_file_name
		    <div><a href="${raw_folder}/${io_statistic}">${io_statistic}</a></div>
EOF
  done
######################################################
  for i in `ls ${input_dir}/${topstat_prefix}*`
  do
     io_statistic=${i##*/}
cat << EOF >> $final_html_file_name
		    <div><a href="${raw_folder}/${io_statistic}">${io_statistic}</a></div>
EOF
  done
cat << EOF >> $final_html_file_name
		<section>
	   </div>
        </div>
        <footer>
		<p>copyright &copy; OSTC@microsoft.com</p>
	</footer>
  </div>    
  </body>
</html>
EOF

}

gen_html_4_storage() {
   local temp_file=$1
   local storage_prefix=$2
   local result_dir=$3
   local raw_dir=$4
   local remote_ip=$5
   local remote_port=$6
   local latency_file=$7
   local gen_latency="0"
   ## generate the data for bar chart
   gen_bar_tbl_data_4_storage $temp_file $result_dir 1 $bs_postfix_bar $storage_prefix
   ## generate the data for table show
   gen_bar_tbl_data_4_storage $temp_file $result_dir 0 $bs_postfix_table $storage_prefix

   if [ $latency_file != "na" ]
   then
       gen_bar_tbl_data_4_storage $latency_file $result_dir 1 $bs_lat_postfix_bar $storage_prefix
       gen_bar_tbl_data_4_storage $latency_file $result_dir 0 $bs_lat_postfix_table $storage_prefix
       gen_latency="1"
   fi
   ## generate html body
   echo "gen_html_file_4_storage $temp_file $storage_prefix $result_dir $raw_dir $remote_ip $remote_port $gen_latency"
   gen_html_file_4_storage $temp_file $storage_prefix $result_dir $raw_dir $remote_ip $remote_port $gen_latency
}

## generate the percentage table for comparing two csv files
gen_percent_tbl() {
   local src_file=$1
   local dst_file=$2
   awk  -F , '
     BEGIN {
		i=1;j=1;
     }
     FILENAME==ARGV[1] {
	if (FNR > 1) {
		data_src[$1]=$0;
		key1[i++]=$1;
	} else {
		orig_title=$0
		split($0,title,",");
		for(k=1;k<=length(title);k++) {
			name2idx[title[k]] = k;
		}
		
	}
     }
     FILENAME==ARGV[2] {
	if (FNR > 1) {
		data_dst[$1]=$0;
		key2[j++]=$1;
	}
     }
     END {
	## handle red configuration
	for (j=1;j<=length(key2);j++) {
		for (i=1;i<=length(key1);i++) {
			if(key1[i] == key2[j]) {
				split(data_src[key1[i]], nsrc, ",");
				split(data_dst[key2[j]], ndst, ",");
				printf("[");
				for(k=1;k<=length(ndst);k++) {
					if (k <= 2) {
					    printf("%d,", nsrc[k]);
					} else {
					    if (is_zero(nsrc[k]) == 0) {
				 		diff=ndst[k]/nsrc[k]*100;
					    } else {
						diff=0;
					    }
					    if (k==3) {
						printf("%.2f",diff);
					    } else {
						printf(",%.2f",diff);
					    }
					}
				}
				printf("],\n");
			}
		}
	}
     }
     function is_zero(n) { 
        m=n;
        if (n < 0) {
	   m=-n;
	}
	return m < 0.001 ? 1 : 0;
     }
     function abs(n) { return n < 0.1 ? -n : n;}
     function isnum(n) { return n ~ /^[+-]?[0-9]+$/ }
     function print_str_array(arr) {
	for (k=1; k<=length(arr);k++) {
		printf("arr[%d]=%s ",k, arr[k]);
	}
	printf("\n");
     }
     function print_int_array(arr) {
        for (k=1; k<=length(arr);k++) {
		printf("arr[%d]=%d \n",k,arr[k]);
	}
	printf("\n");
     }
' $src_file $dst_file
}

## compare for 2 fio csv files
compare2storage() {
   create_tmp_dir_ifnotexist
   local thd=$1
   local src_file=$2
   local dst_file=$3
   local storage_prefix=$4
   local tmp_dst_content_file=$tmp_dir/dst_content.txt
   local tmp_src_content_file=$tmp_dir/src_content.txt
   local red_config_post="_red_config"
   local green_config_post="_green_config"
   local stor_red_config=$(derefer_2vars ${storage_prefix} ${red_config_post})
   local stor_green_config=$(derefer_2vars ${storage_prefix} ${green_config_post})
   local dst_mode_list="" ## sorted
   local dst_iodepth_list=""  ## sorted
   
   ## sort the data according to mode, and remove the title
   awk -v thd="$thd" -F , '{
	if (FNR > 1 && $4 == thd) {
	    print($0);
	}
   }' $dst_file |sort -t , -k 2 >$tmp_dst_content_file
   
   ## sort the data according to mode, and remove the title
   awk -v thd="$thd" -F , '{
	if (FNR > 1 && $4 == thd) {
	    print($0);
	}
   }' $src_file |sort -t , -k 2 >$tmp_src_content_file

   for i in `awk -F , '{print($2)}' $tmp_dst_content_file|uniq`
   do
      dst_mode_list=$dst_mode_list" "$i
   done
   for i in `awk -F , '{print($3)}' $tmp_dst_content_file|sort -n |uniq`
   do
      dst_iodepth_list=$dst_iodepth_list" "$i
   done

   
   awk -v rc="$stor_red_config" -v gc="$stor_green_config" -v d_mode_list="$dst_mode_list" -v d_iodepth_list="$dst_iodepth_list" -F , '
     BEGIN {
		split(rc, red_config_list, ":");
		split(gc, green_config_list, ":");
		for (m=1; m<=length(red_config_list);m++) {
			split(red_config_list[m], config_item, " ");
			red_name_map[config_item[1]]=config_item[2]" "config_item[3]" "config_item[4];
			red_keys[config_item[1]];
		}
		for (m=1; m<=length(green_config_list);m++) {
			split(green_config_list[m], config_item, " ");
			green_name_map[config_item[1]]=config_item[2]" "config_item[3]" "config_item[4];
			green_keys[config_item[1]];
		}
		split(d_mode_list, dst_mode_list, " ");
		split(d_iodepth_list, dst_iodepth_list, " ");
		for (i=1; i<=length(dst_mode_list); i++) {
			mode_idx[dst_mode_list[i]]=i;
		}
		for (i=1; i<=length(dst_iodepth_list); i++) {
			iodepth_idx[dst_iodepth_list[i]]=i;
		}
		k_src=1;
		k_dst=1;
     }
     FILENAME==ARGV[1] {
		key=$2"_"$3"_"$4;
		data_src[key]=$5;
		key_src[k_src++]=key;
     }
     FILENAME==ARGV[2] {
		key=$2"_"$3"_"$4;
		data_dst[key]=$5;
		key_dst[k_dst++]=key;
     }
     END {
	## find the items whose {mode}_{iodepth}_{thread} are equal, and then compute dst/src value
	for (i=1; i <= length(key_dst); i++) {
		for (j=1; j <= length(key_src); j++) {
			if (key_dst[i] == key_src[j]) {
				dst_value=data_dst[key_dst[i]];
				src_value=data_src[key_src[j]];
				split(key_dst[i], mode_iodepth_thd, "_");
				if (mode_iodepth_thd[1] in red_keys) {
					split(red_name_map[mode_iodepth_thd[1]], item, " ");
					if (src_value != "" && src_value != 0) {
						diff=abs((dst_value/src_value-1)*100);
						if ((item[1] == "<=" && dst_value <= src_value) ||
						    (item[1] == ">" && dst_value > src_value)) {
						    if (item[2] == "<=" && diff <= item[3]) {
							print iodepth_idx[mode_iodepth_thd[2]] "," mode_idx[mode_iodepth_thd[1]] ",red";
						    } else if (item[2] == ">" && diff > item[3]) {
							print iodepth_idx[mode_iodepth_thd[2]] "," mode_idx[mode_iodepth_thd[1]] ",red";
						    }
						}
					}
				}
				if (mode_iodepth_thd[1] in green_keys) {
					split(green_name_map[mode_iodepth_thd[1]], item, " ");
					if (src_value != "" && src_value != 0) {
						diff=abs((dst_value/src_value-1)*100);
						if ((item[1] == "<=" && dst_value <= src_value) ||
						    (item[1] == ">" && dst_value > src_value)) {
						    if (item[2] == "<=" && diff <= item[3]) {
							print iodepth_idx[mode_iodepth_thd[2]] "," mode_idx[mode_iodepth_thd[1]] ",green";
						    } else if (item[2] == ">" && diff > item[3]) {
							print iodepth_idx[mode_iodepth_thd[2]] "," mode_idx[mode_iodepth_thd[1]] ",green";
						    }
						}
					}
				}
			}
		}
	}
     }
     function abs(n) { return n < 0.1 ? -n : n;}
     function isnum(n) { return n ~ /^[+-]?[0-9]+$/ }
     function print_str_array(arr) {
	for (k=1; k<=length(arr);k++) {
		printf("arr[%d]=%s ",k, arr[k]);
	}
	printf("\n");
     }
     function print_int_array(arr) {
        for (k=1; k<=length(arr);k++) {
		printf("arr[%d]=%d \n",k,arr[k]);
	}
	printf("\n");
     }
   ' $tmp_src_content_file $tmp_dst_content_file   
}

## This is a private function for generating storage percentage table
compare_4_given_storage_thd() {
    local dst_thd_file=$1
    local src_thd_file=$2
    local result_file=$3
    awk -F , 'BEGIN {
	  m=1;n=1;k=1;
	}
	FILENAME==ARGV[1] {
	   src_mode_value[$2]=$5;
	   src_mode_list[m++]=$2;
	}
	FILENAME==ARGV[2] {
	   dst_mode_value[$2]=$5;
	   dst_mode_list[n++]=$2;
	}
	END {
	   for (i=1; i <= length(dst_mode_list); i++) {
	      matched=0;
	      for (j=1; j <= length(src_mode_list); j++) {
		if (dst_mode_list[i] == src_mode_list[j]) {
		   matched=1;
		   if (src_mode_value[src_mode_list[j]] != "" && src_mode_value[src_mode_list[j]] != 0) {
		      result[k++]=dst_mode_value[dst_mode_list[i]]/src_mode_value[src_mode_list[j]]*100;
		   } else {
		      result[k++]=100;
		   }
		   break;
		}
	      }
	      if (matched == 0) {
		result[k++]=100;
	      }
	   }
	   for (i=1; i <= length(result); i++) {
	      if (i != 1) {
	          printf(",%.2f",result[i]);
	      } else {
		  printf("%.2f",result[i]);
	      }
	   }
	}
    ' $src_thd_file $dst_thd_file > $result_file
}

## Entry for generating storage percentage table
gen_percentage_for_storage() {
    create_tmp_dir_ifnotexist
    local thd=$1
    local src_file=$2
    local dst_file=$3
    local dst_iodepth_list=""
    local dst_mode_list=""
    local tmp_dst_content_file=$tmp_dir/dst_content.txt
    local tmp_src_content_file=$tmp_dir/src_content.txt
    local tmp_dst_thd_file=$tmp_dir/dst_thd_cont.txt
    local tmp_src_thd_file=$tmp_dir/src_thd_cont.txt
    local tmp_result_file=$tmp_dir/tmp_percent.txt
    local i
    ## sort the data according to mode, and remove the title
    awk -v thd="$thd" -F , '{
	if (FNR > 1 && $4 == thd) {
	    print($0);
	}
    }' $dst_file |sort -t , -k 2 >$tmp_dst_content_file
   
    ## sort the data according to mode, and remove the title
    awk -v thd="$thd" -F , '{
	if (FNR > 1 && $4 == thd) {
	    print($0);
	}
    }' $src_file |sort -t , -k 2 >$tmp_src_content_file

    ## find iodepth list
    for i in `awk -F , '{print $3}' $tmp_dst_content_file|sort -n|uniq`
    do
       dst_iodepth_list=${dst_iodepth_list}" $i"
    done
    ## find mode list
    for i in `awk -F , '{print($2)}' $tmp_dst_content_file|uniq`
    do
       dst_mode_list=$dst_mode_list" "$i
    done
    
    for i in $dst_iodepth_list
    do
       grep ",$i,$thd," $tmp_dst_content_file > $tmp_dst_thd_file
       grep ",$i,$thd," $tmp_src_content_file > $tmp_src_thd_file
       compare_4_given_storage_thd $tmp_dst_thd_file $tmp_src_thd_file $tmp_result_file
       echo -n "['$i',"
       cat $tmp_result_file
       echo "],"
    done
}

## compare 2 NIC perf results
compare2nic() {
     local src_file=$1
     local dst_file=$2
     awk -v rc="$red_config" -v gc="$green_config" -F , '
     BEGIN {
		i=1;j=1;
		split(rc, red_config_list, ":");
		split(gc, green_config_list, ":");
		for (m=1; m<=length(red_config_list);m++) {
			split(red_config_list[m], config_item, " ");
			red_name_map[config_item[1]]=config_item[2]" "config_item[3]" "config_item[4];
		}
		for (m=1; m<=length(green_config_list);m++) {
			split(green_config_list[m], config_item, " ");
			green_name_map[config_item[1]]=config_item[2]" "config_item[3]" "config_item[4];
		}

     }
     FILENAME==ARGV[1] {
	if (FNR > 1) {
		data_src[$1]=$0;
		key1[i++]=$1;
	} else {
		split($0,title,",");
		for(k=1;k<=length(title);k++) {
			name2idx[title[k]] = k;
		}
		
	}
     }
     FILENAME==ARGV[2] {
	if (FNR > 1) {
		data_dst[$1]=$0;
		key2[j++]=$1;
	}
     }
     END {
	## handle red configuration
	for (j=1;j<=length(key2);j++) {
		for (i=1;i<=length(key1);i++) {
			if(key1[i] == key2[j]) {
				split(data_src[key1[i]], nsrc, ",");
				split(data_dst[key2[j]], ndst, ",");
				for (x in red_name_map) {
				    split(red_name_map[x], item, " ");
				    if (is_zero(nsrc[name2idx[x]]) == 0) {
					diff=abs((ndst[name2idx[x]]/nsrc[name2idx[x]]-1)*100);
					if ((item[1] == "<=" && ndst[name2idx[x]] <= nsrc[name2idx[x]]) ||
					    (item[1] == ">" && ndst[name2idx[x]] > nsrc[name2idx[x]])) {
					    if (item[2] == "<=" && diff <= item[3]) {
						print min(j, i) "," name2idx[x] ",red";
					    } else if (item[2] == ">" && diff > item[3]) {
						print min(j, i) "," name2idx[x] ",red";
					    }
					}
				    }
				}
				for (x in green_name_map) {
				    split(green_name_map[x], item, " ");
				    if (is_zero(nsrc[name2idx[x]]) == 0) {
					diff=abs((ndst[name2idx[x]]/nsrc[name2idx[x]]-1)*100);
					if (item[1] == "<=" && ndst[name2idx[x]] <= nsrc[name2idx[x]] ||
					    item[1] == ">" && ndst[name2idx[x]] > nsrc[name2idx[x]]) {
					    if (item[2] == "<=" && diff <= item[3]) {
						print min(j, i) "," name2idx[x] ",green"; 
					    } else if (item[2] == ">" && diff > item[3]) {
						print min(j, i) "," name2idx[x] ",green";
					    }
					}
				    }
				}
			}
		}
	}
     }
     function is_zero(n) { 
        m=n;
        if (n < 0) {
	   m=-n;
	}
	return m < 0.001 ? 1 : 0;
     }
     function abs(n) { return n < 0.1 ? -n : n;}
     function min(a, b) { return a < b ? a : b;}
     function isnum(n) { return n ~ /^[+-]?[0-9]+$/ }
     function print_str_array(arr) {
	for (k=1; k<=length(arr);k++) {
		printf("arr[%d]=%s ",k, arr[k]);
	}
	printf("\n");
     }
     function print_int_array(arr) {
        for (k=1; k<=length(arr);k++) {
		printf("arr[%d]=%d \n",k,arr[k]);
	}
	printf("\n");
     }
' $src_file $dst_file
}

## Merge the iops or latency normal csv file to a single one.
## It is helpful to open one file to see all.
## @param 1: the fio_result dir
## We suppose the *normal_csv is like:
#
# file name: 4k_1_bs_tbl_normal_csv
#
# content:
#
# IOdepth,randread,randwrite,read,write,
# '1',7231.71,37429.7,39217.1,37992.6
# '16',83296.2,64293,63198.1,66137.5
# '32',90385.4,63815,63583,65690.8
# '64',90269.4,62441.7,62515.5,63184
# '128',82807.5,59300.2,61225.2,60706.9
# '256',68305.2,51725.8,77993.1,53022.1
fio_merge_csv() {
  local dir=$1
  local iops_postfix="bs_tbl_normal_csv"
  local lat_postfix="bs_lat_tbl_normal_csv"
  local iops_out="iops.csv"
  local lat_out="lat.csv"
  cd $dir
  echo "IOPS" > $iops_out  ## echo the title
  for i in `ls *${iops_postfix} | sort -t _ -k 1 -k 2 -n`
  do
     #local col=`head -n 2 $i|awk -F , '{print NF}'`
     local bs=`echo $i|awk -F _ '{print $1}'`
     local th=`echo $i|awk -F _ '{print $2}'`
     echo "${bs},${th}th" >> $iops_out
     cat $i >> $iops_out
     echo "," >> $iops_out
  done

  echo "Latency" > $lat_out
  for i in `ls *${lat_postfix} | sort -t _ -k 1 -k 2 -n`
  do
     local bs=`echo $i|awk -F _ '{print $1}'`
     local th=`echo $i|awk -F _ '{print $2}'`
     echo "${bs},${th}th" >> $lat_out
     cat $i >> $lat_out
     echo "," >> $lat_out

  done
  cd -
}
## generate html according to raw fio data.
## @param 1: the dir where the raw data locates
## @param 2: dir for results
parse_fio_data() {
  local dir=$1
  local raw_data_csv_postfix=_${fio_prefix}${csv_table_file_postfix}
  local raw_latency_file_postfix=_${fio_prefix}_latency${csv_table_file_postfix}
  local output_dir=$2
  local tmp_file=$tmp_dir/fio_iops_output.txt
  local lat_file=$tmp_dir/fio_lat_output.txt
  local bs_postfix_bar=$bs_postfix_bar
  local bs_postfix_table=$bs_postfix_table
  local bs_list=""
  local mode_list=""

  create_tmp_dir_ifnotexist
  #check_disk_info $fio_remote_ip

  if [ -e $tmp_file ]
  then
     rm $tmp_file
  fi
  if [ -e $lat_file ]
  then
     rm $lat_file
  fi
  if [ ! -d $output_dir ]
  then
     mkdir $output_dir
  else
     rm $output_dir/*
  fi
  for i in `ls $dir/${fio_prefix}*.json`
  do
     json_file=${i##*/}
     bs=`echo $json_file|awk -F - '{print $4}'`
     echo "BlockSize,Mode,IOdepth,Thread,IOPS" > ${output_dir}/${bs}${raw_data_csv_postfix}
     echo "BlockSize,Mode,IOdepth,Thread,Latency" > ${output_dir}/${bs}${raw_latency_file_postfix}
  done
  for i in `ls $dir/${fio_prefix}*.json`
  do
     local json_file=${i##*/}
     local jbname=`echo $json_file|awk -F - '{print $2}'`
     local mode=`echo $json_file|awk -F - '{print $3}'`
     local bs=`echo $json_file|awk -F - '{print $4}'`
     local iodepth=`echo $json_file|awk -F - '{print $5}'`
     local thread=`echo $json_file|awk -F - '{print $6}'|awk -F . '{print $1}'`
     op=`echo ""|awk -v s=$mode '{if (s ~ /read/) print "read"; if (s ~ /write/) print "write"}'`
     iops=`python2.7 $fio_parser $i "jobs/jobname=$jbname/$op/iops"|awk '{s+=$1}END{print s}'` ## group iops for multiple threads
     lat=`python2.7 $fio_parser $i "jobs/jobname=$jbname/$op/lat/mean"|sort -r -n|head -n 1`   ## pick the 1st for ungroup running
     echo "${bs}/${mode}/${iodepth}/${thread}/${iops}" >> $tmp_file
     echo "${bs},${mode},${iodepth},${thread},${iops}" >> ${output_dir}/${bs}${raw_data_csv_postfix}
     echo "${bs}/${mode}/${iodepth}/${thread}/${lat}" >> $lat_file
     echo "${bs},${mode},${iodepth},${thread},${lat}" >> ${output_dir}/${bs}${raw_latency_file_postfix}
  done
  ## generate html body
  gen_html_4_storage $tmp_file $fio_prefix $output_dir $dir $storage_remote_ip $storage_remote_port $lat_file
  fio_merge_csv ${output_dir}
}

## generate html for sysbench
## @param1: raw data directory
## @param2: result directory
parse_sysbench_data() {
   local input_dir=$1
   local output_dir=$2
   local sysbench_csv_table_postfix=_${sysbench_prefix}${csv_table_file_postfix}
   local raw_file=$tmp_dir/sysbench_raw.txt
   local file_name
   local config_name
   local mode
   local thread
   local bs
   local iops

   create_tmp_dir_ifnotexist
   if [ -e $raw_file ]
   then
      rm $raw_file
   fi
   if [ ! -d $output_dir ]
   then
     mkdir $output_dir
   else
     rm $output_dir/*
   fi
   for i in `ls $input_dir/*.result`
   do
      iops=`grep "Requests/sec executed" $i|awk '{printf("%.2f",$1)}'`
      file_name=${i##*/}
      config_name=`echo $file_name|awk -F . '{print $1}'`
      bs=`echo $config_name|awk -F - '{print $4}'`
      echo "BlockSize,Mode,Thread,IOPS" > ${output_dir}/${bs}${sysbench_csv_table_postfix}
   done

   for i in `ls $input_dir/*.result`
   do
      iops=`grep "Requests/sec executed" $i|awk '{printf("%.2f",$1)}'`
      file_name=${i##*/}
      config_name=`echo $file_name|awk -F . '{print $1}'`
      mode=`echo $config_name|awk -F - '{print $2}'`
      thread=`echo $config_name|awk -F - '{print $3}'`
      bs=`echo $config_name|awk -F - '{print $4}'`
      echo "${bs}/${mode}/1iodepth/${thread}/${iops}" >> $raw_file ## 1 means in flight request number is 1, in order to be compatiable with fio
      echo "${bs},${mode},1iodepth,${thread},${iops}" >> ${output_dir}/${bs}${sysbench_csv_table_postfix}
   done
   ## generate html body
   gen_html_4_storage $raw_file $sysbench_prefix $output_dir $input_dir $storage_remote_ip $storage_remote_port "na"
}

parse_sio_data() {
  local dir=$1
  local raw_data_csv_postfix=_${sio_prefix}${csv_table_file_postfix}
  local output_dir=$2
  local tmp_file=$tmp_dir/sio_iops_output.txt
  local bs_postfix_bar=$bs_postfix_bar
  local bs_postfix_table=$bs_postfix_table
  local bs_list=""
  local mode_list=""

  create_tmp_dir_ifnotexist
  #check_disk_info $fio_remote_ip

  if [ -e $tmp_file ]
  then
     rm $tmp_file
  fi
  if [ ! -d $output_dir ]
  then
     mkdir $output_dir
  else
     rm $output_dir/*
  fi
  for i in `ls $dir/${sio_prefix}*.out`
  do
     out_file=${i##*/}
     bs=`echo $out_file|awk -F - '{print $4}'`
     echo "BlockSize,Mode,Thread,IOPS" > ${output_dir}/${bs}${raw_data_csv_postfix}
  done
  for i in `ls $dir/${sio_prefix}*.out`
  do
     out_file=${i##*/}
     jbname=`echo $out_file|awk -F - '{print $2}'`
     mode=`echo $out_file|awk -F - '{print $3}'`
     bs=`echo $out_file|awk -F - '{print $4}'`
     thread=`echo $out_file|awk -F - '{print $5}'|awk -F . '{print $1}'`
     iops=`grep "IOPS" $i|awk '{print $2}'`
     echo "${bs}/${mode}/1iodepth/${thread}/${iops}" >> $tmp_file ## 1 means in flight request number is 1, it is compitable with fio
     echo "${bs},${mode},1iodepth,${thread},${iops}" >> ${output_dir}/${bs}${raw_data_csv_postfix}
  done
  ## generate html body
  gen_html_4_storage $tmp_file $sio_prefix $output_dir $dir $storage_remote_ip $storage_remote_port "na"
}

distribute_kernel() {
   local kernel_zip=$1
   local remote_server=$2
   local remote_port=$3
   local remote_user=$4
   log "scp -P ${remote_port} $kernel_zip ${remote_user}@${remote_server}:/boot/"
   scp -P ${remote_port} $kernel_zip ${remote_user}@${remote_server}:/boot/
   log "ssh ${remote_user}@${remote_server} -p ${remote_port} cd /boot/; tar zxvf $kernel_zip"
   ssh ${remote_user}@${remote_server} -p ${remote_port} "cd /boot/; tar zxvf $kernel_zip"
}

## NUMA node preference for nightly performance test VM.
## The 1st VM started will take node 1, and 2nd VM started will take node 0.
## Only VM on node 0 can get best performance.
reboot_machine() {
   local remote_ip=$1
   local remote_port=$2
   if [ "$need_reboot" == "yes" ]
   then
      log "ssh root@${remote_ip} -p ${remote_port} reboot"
      ssh root@${remote_ip} -p ${remote_port} reboot
   fi
}

start_VM_with_prefered_NUMA() {
   local remote_ip_1st_started=$1  ## on NUMA node 1, selected by OS
   local remote_port_1st_started=$2
   local remote_ip_2nd_started=$3  ## on NUMA node 0, selected by OS
   local remote_port_2nd_started=$4
   local delay=$5
   reboot_machine $remote_ip_1st_started $remote_port_1st_started
   sleep $delay
   reboot_machine $remote_ip_2nd_started $remote_port_2nd_started
   sleep $delay
}

reboot_considering_NUMA() {
   local primary_ip=$1
   local primary_port=$2
   local secondary_ip=$3
   local secondary_port=$4
   local delay=200
   case "$choose_NUMA" in
      "0") 
	start_VM_with_prefered_NUMA $secondary_ip $secondary_port $primary_ip $primary_port $delay
	;;
      "1")
	start_VM_with_prefered_NUMA $primary_ip $primary_port $secondary_ip $secondary_port $delay
	;;
      "no")
	reboot_machine $primary_ip $primary_port
	sleep $delay
   esac
}

reboot_perf04() {
   if [ "$need_reboot" == "yes" ]
   then
      reboot_considering_NUMA $perf04_corp_ip $perf04_corp_port $perf04_dummy_server_ip $perf04_dummy_server_port
   fi
}

reboot_perf03() {
   if [ "$need_reboot" == "yes" ]
   then
      reboot_considering_NUMA $perf03_corp_ip $perf03_corp_port $perf03_dummy_server_ip $perf03_dummy_server_port
   fi
}

reboot_storage_server() {
   if [ "$need_reboot" == "yes" ]
   then
      reboot_considering_NUMA $storage_remote_ip $storage_remote_port $storage_dummy_server_ip $storage_dummy_server_port
   fi
}

## internal ip configuration
internal_ip_config()
{
    if [ "$config_internal_ip" == "yes" ]
    then
	scp -o "StrictHostKeyChecking no" -i $ssh_id_path -P ${perf03_corp_port} ${base}/config_ip.sh root@${perf03_corp_ip}:~
	log "scp -i $ssh_id_path -P ${perf03_corp_port} ${base}/config_ip.sh root@${perf03_corp_ip}:~"
	ssh -o "StrictHostKeyChecking no" root@${perf03_corp_ip} -p ${perf03_corp_port} "sh $config_ip_sh ${perf03_inter_ip}"
	log "ssh root@${perf03_corp_ip} -p ${perf03_corp_port} sh $config_ip_sh ${perf03_inter_ip}"

	scp -i $ssh_id_path -P ${perf04_corp_port} ${base}/config_ip.sh root@${perf04_corp_ip}:~
	log "scp -i $ssh_id_path -P ${perf04_corp_port} ${base}/config_ip.sh root@${perf04_corp_ip}:~"
	ssh root@${perf04_corp_ip} -p ${perf04_corp_port} "sh $config_ip_sh ${perf04_inter_ip}"
	log "ssh root@${perf04_corp_ip} -p ${perf04_corp_port} sh $config_ip_sh ${perf04_inter_ip}"
	output_state_msg "internal_ip_config"
    else
	log "no need to config internal ip"
    fi
}

####################### net drv framework ####################
run_single_netdrv()
{
	local remote_corp_ip=$1
	local remote_corp_port=$2
	local netdrv_script=$3
	local ifstat_file=$4
	local result_file=$5
	local top_file=$6
	local ethernet=$7
	local netdrv=$8
	local dur=$9
	local result_folder=$curr_result_dir/$netdrv
	local log_tag=$netdrv

	scp -P ${remote_corp_port} $netdrv_script test@${remote_corp_ip}:~/
	scp -P ${remote_corp_port} $top_monitor_sh test@${remote_corp_ip}:~/
	scp -P ${remote_corp_port} $netdrv_wrapper_sh test@${remote_corp_ip}:~/

	log "ssh test@${remote_corp_ip} -p ${remote_corp_port} sh $netdrv_wrapper_sh $ethernet $log_tag $dur $ifstat_file $top_file $top_monitor_sh $netdrv_script"
	ssh test@${remote_corp_ip} -p ${remote_corp_port} "sh $netdrv_wrapper_sh $ethernet $log_tag $dur $ifstat_file $top_file $top_monitor_sh $netdrv_script"

	if [ ! -e $result_folder ]
	then
		mkdir $result_folder
	fi
		
	scp -P ${remote_corp_port} test@${remote_corp_ip}:~/$ifstat_file $result_folder/
	log "scp -P ${remote_corp_port} test@${remote_corp_ip}:~/$ifstat_file $result_folder/"
	scp -P ${remote_corp_port} test@${remote_corp_ip}:~/$result_file $result_folder/
	log "scp -P ${remote_corp_port} test@${remote_corp_ip}:~/$result_file $result_folder/"
	scp -P ${remote_corp_port} test@${remote_corp_ip}:~/$top_file $result_folder/
	log "scp -P ${remote_corp_port} test@${remote_corp_ip}:~/$top_file $result_folder/"
}

## @return the number of server process
search_netdrv_server()
{
	local remote_ip=$1
	local remote_port=$2
	local netdrv_prefix=$3
	log "ssh test@${remote_ip} -p $remote_port ps axu|grep $netdrv_prefix|wc -l "
	ret=`ssh test@${remote_ip} -p $remote_port ps axu|grep $netdrv_prefix|wc -l`
	echo $ret
}
################## netperf test ################
distribute_tcpstream_drv()
{
	local remote_ip=$1
	local remote_port=$2
	log "scp -P ${remote_port} $tcpstream_pkg test@$remote_ip:~"
	scp -P ${remote_port} $tcpstream_pkg test@$remote_ip:~
	log "ssh test@$remote_ip -p ${remote_port} tar zxvf $tcpstream_pkg"
	ssh test@$remote_ip -p ${remote_port} "tar zxvf $tcpstream_pkg"
	ssh test@${remote_ip} -p ${remote_port} "cd $tcpstream; make"
	log "ssh test@${remote_ip} -p ${remote_port} cd $tcpstream; make"
	log "finish distribute_tcpstream_drv on $remote_ip:$remote_port"
}

## 
launch_netserver()
{
	local remote_ip=$1
	local remote_port=$2
	local status
	log "ssh test@${remote_ip} -p $remote_port netserver"
	status=`ssh test@${remote_ip} -p $remote_port "netserver"`
	log "launch netserver result: \"$status\""
}

## generate the netdrv script for netperf
# @param1: internal server ip
# @param2: duration for the test
# @param3: connection
# @param4: result file
# @param5: log tag for logger
# @param6: the script file for netperf
gen_netperf_script()
{
	local remote_netserver=$1
	local dur=$2
	local conn=$3
	local result_file=$4
	local script_out_file=$5
	local log_tag=$netperf_prefix

cat << EOF > $script_out_file
logger -t $log_tag "$tcpstream/$tcpstream -H $remote_netserver -l $dur -i $conn >$result_file"
$tcpstream/$tcpstream -H $remote_netserver -l $dur -i $conn >$result_file
EOF
}

run_netdrv_netperf() {
	local dur=$1
	local ethernet=$2
	local netperf_script=./autogen_netdrv_run_${netperf_prefix}.sh
	
	local result_file
	local ifstat_file
	local top_file
	for i in $connection_iter
	do
		if [ $i -le 2048 ]
		then
			result_file=${netperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_result.txt
			ifstat_file=${netperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${ifstat_postfix}.txt
			top_file=${netperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${top_postfix}.txt
			gen_netperf_script ${perf03_inter_ip} $dur $i $result_file $netperf_script

			run_single_netdrv $perf04_corp_ip $perf04_corp_port $netperf_script $ifstat_file $result_file $top_file $ethernet $netperf_prefix $dur
		fi
	done
}

################## kq_netperf for BIS ###############
distribute_kq_netperf_drv()
{
	local remote_ip=$1
	local remote_port=$2

	log "scp -P ${remote_port} $kq_netperf_pkg test@${remote_ip}:~"
	scp -P ${remote_port} $kq_netperf_pkg test@${remote_ip}:~
	log "ssh test@${remote_ip} -p ${remote_port} tar zxvf $kq_netperf_pkg"
	ssh test@${remote_ip} -p ${remote_port} "tar zxvf $kq_netperf_pkg"

	log "finish distribute kq_netperf_pkg perf tester"
}

launch_kqnetperf_server()
{
	local remote_ip=$1
	local remote_port=$2
	local hw_ncpu
	local ncpu
	local os=`ssh test@$remote_ip -p $remote_port uname`
        hw_ncpu=$(get_cpu_core $remote_ip $remote_port)
	ncpu=`expr $hw_ncpu + $hw_ncpu`
	log "ssh test@${remote_ip} -p $remote_port $kq_netperf/$kq_netperf_srv -t $ncpu"
	ssh test@${remote_ip} -p $remote_port "$kq_netperf/$kq_netperf_srv -t $ncpu"
}

## generate the netdrv script for netperf
# @param1: internal server ip
# @param2: duration for the test
# @param3: connection
# @param4: result file
# @param5: log tag for logger
# @param6: the script file for netperf
gen_kqnetperf_script()
{
	local remote_netserver=$1
	local dur=$2
	local conn=$3
	local thread=$4
	local result_file=$5
	local script_out_file=$6
	local log_tag=$kq_netperf_prefix

cat << EOF > $script_out_file
logger -t $log_tag "$kq_netperf/$kq_netperf -4 $remote_netserver -l $dur -c $conn -t $thread >$result_file"
$kq_netperf/$kq_netperf -4 $remote_netserver -l $dur -c $conn -t $thread >$result_file
EOF
}

run_netdrv_kqnetperf() {
	local dur=$1
	local ethernet=$2
	local kqnetperf_script=./autogen_netdrv_run_${kq_netperf_prefix}.sh
	
	local result_file
	local ifstat_file
	local top_file
	local ncpu=$(get_cpu_core $perf04_corp_ip $perf04_corp_port)
	local os=`ssh test@$perf04_corp_ip -p $perf04_corp_port uname`

	local thread=`expr $ncpu + $ncpu`
	for i in $connection_iter
	do
		result_file=${kq_netperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_result.txt
		ifstat_file=${kq_netperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${ifstat_postfix}.txt
		top_file=${kq_netperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${top_postfix}.txt
		gen_kqnetperf_script ${perf03_inter_ip} $dur $i $thread $result_file $kqnetperf_script

		run_single_netdrv $perf04_corp_ip $perf04_corp_port $kqnetperf_script $ifstat_file $result_file $top_file $ethernet $kq_netperf_prefix $dur
	done
}
################## iperf #############
## return 0 if successfully stop iperf server
stop_iperf_server()
{
	local remote_ip=$1
	local remote_port=$2
	local iperf_search
	iperf_search=$(search_netdrv_server $remote_ip $remote_port $iperf_prefix)
	if [ $iperf_search != 0 ]
	then
		ssh test@${remote_ip} -p ${remote_port} killall -9 $iperf_prefix
	fi

	iperf_search=$(search_netdrv_server $remote_ip $remote_port $iperf_prefix)
	if [ $iperf_search == 0 ]
	then
		echo 0
	else
		echo 1
	fi
}

## @return 0 if the iperf servers were successfully launched as expected
launch_iperf_server()
{
	local remote_ip=$1
	local remote_port=$2
	local n=1
	local port=$iperf_server_port_start
	local iperf_search=$(search_netdrv_server $remote_ip $remote_port $iperf_prefix)
	if [ $iperf_search != $iperf_server_port_serie_len ]
	then
		stop_iperf_server $remote_ip $remote_port
		ssh test@${remote_ip} -p ${remote_port} "rm iperf_server.txt"
		while [ $n -le $iperf_server_port_serie_len ]
		do
			log "ssh test@${remote_ip} -p ${remote_port} \"nohup iperf -s -D -p $port >> iperf_server.txt &\" > /dev/null"
			ssh test@${remote_ip} -p ${remote_port} "nohup iperf -s -D -p $port >> iperf_server.txt &" > /dev/null ## ignore the output to stdout
			n=`expr $n + 1`
			port=`expr $port + 1`
		done
	fi
	iperf_search=$(search_netdrv_server $remote_ip $remote_port $iperf_prefix)
	if [ $iperf_search == $iperf_server_port_serie_len ]
	then
		echo 0
	else
		echo 1
	fi
}

gen_iperf_script()
{
	local remote_netserver=$1
	local remote_server_port_start=$2
	local dur=$3
	local conn=$4
	local maxconn=$5
	local result_file=$6
	local script_out_file=$7
	local log_tag=$iperf_prefix
	if [ $conn -le $maxconn ]
	then
cat << EOF > $script_out_file
#!/bin/sh
logger -t $log_tag "nohup iperf -c $remote_netserver -p $remote_server_port_start -t $dur -P $conn > $result_file &"
nohup iperf -c $remote_netserver -p $remote_server_port_start -t $dur -P $conn > $result_file &
EOF
	else
cat << EOF > $script_out_file
#!/bin/sh
tconn=$conn
tport=$remote_server_port_start
while [ \$tconn -ge $maxconn ]
do
   logger -t $log_tag "nohup iperf -c $remote_netserver -p \$tport -t $dur -P $maxconn > $result_file &"
   nohup iperf -c $remote_netserver -p \$tport -t $dur -P $maxconn > $result_file &
   tconn=\`expr \$tconn - \$maxconn\`
   tport=\`expr \$tport + 1\`
done
if [ \$tconn -ne 0 ]
then
   logger -t $log_tag "nohup iperf -c $remote_netserver -p \$tport -t $dur -P \$tconn > $result_file &"
   nohup iperf -c $remote_netserver -p \$tport -t $dur -P \$tconn > $result_file &
fi
EOF
	fi
}

run_netdrv_iperf()
{
	local dur=$1
	local ethernet=$2
	local iperf_script=./autogen_netdrv_run_${iperf_prefix}.sh
	
	local result_file
	local ifstat_file
	local top_file
	for i in $connection_iter
	do
		result_file=${iperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_result.txt
		ifstat_file=${iperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${ifstat_postfix}.txt
		top_file=${iperf_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${top_postfix}.txt
		gen_iperf_script ${perf03_inter_ip} $iperf_server_port_start $dur $i $iperf_client_max_conn $result_file $iperf_script

		run_single_netdrv $perf04_corp_ip $perf04_corp_port $iperf_script $ifstat_file $result_file $top_file $ethernet $iperf_prefix $dur
	done
}
################## ntttcp test for LIS ##############
launch_ntttcp_server() {
   local remote_ip=$1
   local remote_port=$2
   local server_internal_ip=$3
   local mapping=$4
   local ntttcp_proc=`ssh test@$remote_ip -p $remote_port ps aux|grep ntttcp|wc -l|awk '{print $1}'`
   if [ "$ntttcp_proc" == "1" ]
   then
       log "ntttcp server is running, and we need to restart it"
       ntttcp_proc=`ssh test@$remote_ip -p $remote_port ps aux|grep ntttcp|awk '{print $2}'`
       ssh test@$remote_ip -p $remote_port kill -9 $ntttcp_proc
       ntttcp_proc=`ssh test@$remote_ip -p $remote_port ps aux|grep ntttcp|wc -l|awk '{print $1}'`
       if [ $ntttcp_proc == "1" ]
       then
          log "Fail to stop ntttcp by killing its process"
          echo 1
          return
       fi
   fi
   log "ssh test@$remote_ip -p $remote_port ntttcp -D -r -e -m $mapping"
   ssh test@$remote_ip -p $remote_port "ntttcp -D -r -e -m $mapping"
   ntttcp_proc=`ssh test@$remote_ip -p $remote_port ps aux|grep ntttcp|wc -l|awk '{print $1}'`
   if [ "$ntttcp_proc" == "0" ]
   then
      log "Fail to start ntttcp"
      echo 1
      return
   else
      log "Successfully launch ntttcp"
   fi
   echo 0
}

gen_ntttcp_client_script() {
   local mapping=$1
   local conn=$2
   local dur=$3
   local result_file=$4
   local script=$5
   local log_tag=${ntttcp_prefix}
cat << EOF > $script
logger -t $log_tag "ntttcp -s -t $dur -e -m $mapping -n $conn -V > $result_file"
ntttcp -s -t $dur -e -m $mapping -n $conn -V > $result_file
EOF
}

## @param1: duration for the test
## @param2: ethernet interface on sender side, which is used by ifstat to track net throughput
run_netdrv_ntttcp() {
	local dur=$1
	local ethernet=$2
	local ntttcp_script=./netdrv_run_${ntttcp_prefix}.sh
	
	local result_file
	local ifstat_file
	local top_file
	local mapping
	local connection
	for i in $connection_iter
	do
	    if [ $i -le 4096 ]
	    then
		if [ $i -le 8 ]
		then
			mapping="$i,*,$perf03_inter_ip"
			connection=1
		else
			mapping="8,*,$perf03_inter_ip"
			connection=`echo""|awk -v conn=$i '{printf("%d", conn/8)}'`
			
		fi
		local launch_stat=$(launch_ntttcp_server $perf03_corp_ip $perf03_corp_port $perf03_inter_ip "$mapping")
		if [ $launch_stat != "0" ]
		then
			log "Stop running ntttcp"
			break
		fi
		result_file=${ntttcp_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_result.txt
		ifstat_file=${ntttcp_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${ifstat_postfix}.txt
		top_file=${ntttcp_prefix}_${duration}_${perf04_inter_ip}_${perf03_inter_ip}_${i}_${top_postfix}.txt
		gen_ntttcp_client_script ${mapping} $connection $dur $result_file $ntttcp_script

		run_single_netdrv $perf04_corp_ip $perf04_corp_port $ntttcp_script $ifstat_file $result_file $top_file $ethernet $ntttcp_prefix $dur
	    fi
	done
}

send_mail()
{
   local html_summary_path=$1
   local result_folder=$2
   local subject_tag=$3
   local web_port=$4
   local subject=${subject_prefix}${result_folder}
   local server_ip=`ifconfig hn0 | grep "inet "|awk '{print $2}'`
   html_href="${web_protocol}://${server_ip}:${web_port}/${result_folder}/$summary_html_file"

   cat << EOF > /tmp/send_mail.txt
subject:<${subject_tag}>$subject</${subject_tag}>
from:$from
Performance result:
   $html_href
EOF

   cat << EOF >> /tmp/send_mail.txt

**Auto generated mail. Never reply it.**
EOF
   if [ "$use_mailclient" == "yes" ]
   then
      local url
      url="http://"${mailhost}:${mailserverport}"/vm2ip/rest/getip?vm="${mailvm}"&host="${mailhost}
      local mailclient=`curl -b GET "$url" | awk -F : '{print $2}' | tr -d '\015\012'`
      if [ "$mailclient" != "" ]
      then
          log "scp /tmp/send_mail.txt honzhan@${mailclient}:/tmp/"
          scp /tmp/send_mail.txt honzhan@${mailclient}:/tmp/
          ssh honzhan@$mailclient "sendmail $receivers_list < /tmp/send_mail.txt"
      else
          log "mail client is failed to find!"
      fi
   else
      sendmail $receivers_list < /tmp/send_mail.txt
   fi
}
################## generate html ####
g_final_output_body1=""
g_final_output_body1=""
g_ifstat_desc=""

gen_view_html()
{
   local title="$1"
   local subtitle="$2"
   local indata_dir=$3
   local perf_tool=$4
   local test_start_time=`cat $status_dir/$start_time`
   local test_end_time=`cat $status_dir/$end_time`
   local perf04_tunable_option=$(get_tunable_option $perf04_corp_ip $perf04_corp_port)
   local perf03_tunable_option=$(get_tunable_option $perf03_corp_ip $perf03_corp_port)
   local perf04_sysctl_values=$(get_sysctl_option_list_values $perf04_corp_ip $perf04_corp_port $perf04_inter_ip)
   local perf03_sysctl_values=$(get_sysctl_option_list_values $perf03_corp_ip $perf03_corp_port $perf03_inter_ip)
   local top_file=""
   local out_dir=$(get_folder_from_path $indata_dir)
   local csv_chart_file=${perf_tool}${csv_chart_file_postfix}
   local csv_table_file=${perf_tool}${csv_table_file_postfix}

   for i in `ls -t $indata_dir/*${top_postfix}*`
   do
       top_file=${i##*/}
       
   done

   cat $html_header_tmpl > $final_output_file
cat << _EOF >> $final_output_file
    <script type="text/javascript">
      google.charts.load('current', {'packages':['line', 'table']});
      google.charts.setOnLoadCallback(drawChart);
      google.charts.setOnLoadCallback(drawTable);

    function drawChart() {
      var data = new google.visualization.DataTable();
      data.addColumn('number', 'Duration (sec)');
_EOF
## data for chart
   echo -e "$g_final_output_body1" >> $final_output_file
   echo "data.addRows([" >> $final_output_file
   cat $data_file >> $final_output_file
   echo "      ]);" >> $final_output_file
##
cat << EOF_ >> $final_output_file
      var options = {
        chart: {
          title: "$title",
          subtitle: "$subtitle"
        },
        width: 1500,
        height: 1000
      };

      var chart = new google.charts.Line(document.getElementById('linechart_material'));

      chart.draw(data, options);
    }

    function drawTable() {
	var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
	var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
	var data = new google.visualization.DataTable();
	data.addColumn('number', 'Connections');
        data.addColumn('number', 'Duration(s)');
        data.addColumn('number', 'Min(Gbps)');
        data.addColumn('number', 'Max(Gbps)');
	data.addColumn('number', 'Median(Gbps)');
	data.addColumn('number', 'Avg(Gbps)');
	data.addColumn('number', 'Stddev(Mbps)');
        data.addRows([
EOF_

# data for table
   cat $g_table_data_file >> $final_output_file
#
cat << E_O_F >> $final_output_file
        ]);

        var table = new google.visualization.Table(document.getElementById('table_div'));
        
        table.draw(data, options);
    }
  </script>
</head>
<body>
  <div class="container">
        <header>
            <h1>Network Performance Report</h1>
        </header>
        <div class="wrapper clearfix">
	  <div class="content">
                <section>
                    <h2>Environment</h2>
			<p>Time used for the whole run: from <b>"$test_start_time"</b> to <b>"$test_end_time"</b>.<p>
			<b>Environment for $perf04_corp_ip:$perf04_corp_port</b><br>
			<ul>
			    <li>CPU: $perf04_cpu_core</li>
			    <li>CPU details: "$perf04_cpu_info"</li>
			    <li>OS: "$perf04_uname"</li>
			    <li>tunable: "$perf04_tunable_option"</li>
			    <li>sysctl: "$perf04_sysctl_values"</li>
			    <li>static memory: "${perf04_mem}"</li>
			</ul>
		        <b>Environment for $perf03_corp_ip:$perf03_corp_port</b>
			<ul>
			    <li>CPU: $perf03_cpu_core</li>
			    <li>CPU details: "$perf03_cpu_info"</li>
			    <li>OS: "$perf03_uname"</li>
			    <li>tunable: "$perf03_tunable_option"</li>
			    <li>sysctl: "$perf03_sysctl_values"</li>
			    <li>static memory: "${perf03_mem}"</li>
			</ul>
		</section>
	  </div>
	  <div class="content">
                <section>
		    <h2>Result</h2>
		    <div><a href="$csv_table_file">Export table data to csv</a></div>
		    <div id="table_div"></div>
  		    <div><a href="$csv_chart_file">Export chart data to csv</a></div>
		    <div id="linechart_material"></div><br>
		</section>
	  </div>
E_O_F
   ## add statistics for top/vmstat if they are collected
   top_statistic=`ls -t $indata_dir/*${top_postfix}*`
   if [ "$top_statistic" != "" ]
   then
cat << EOF >> $final_output_file
          <div class="content">
                <section>
                    <h2>Statistics</h2>
EOF
	for i in `ls -t $indata_dir/*${top_postfix}*`
	do
		top_file=${i##*/}
cat << EOF >> $final_output_file
		    <div><a href="$out_dir/$top_file">$top_file</a></div>
EOF
	done
cat << EOF >> $final_output_file
		</section>
          </div>
EOF
   fi
cat << E_O_F >> $final_output_file
	</div>
	<footer>
		<p>copyright &copy; OSTC@microsoft.com</p>
	</footer>
  </div>
</body>
</html>
E_O_F
   log "Done in gen_view_html"
}

init_blank_result()
{
   if [ -e $data_file ]
   then
       rm $data_file
   fi
   local iter=1
   while [ $iter -le $duration ]
   do
       echo "[$iter" >> $data_file
       iter=`expr $iter + 1`
   done
}

init_end_column()
{
   if [ -e $end_file ]
   then
       rm $end_file
   fi
   iter=1
   while [ $iter -le $duration ]
   do
       echo "]," >> $end_file
       iter=`expr $iter + 1`
   done
}

gen_final_body1()
{
   local conn=$1
   local newline="\n"
   g_final_output_body1=${g_final_output_body1}"      data.addColumn('number', '${conn} connections');"${newline}
}

collect_netperf_result()
{
   local dir=$1
   local prefix=$2
   local con
   local column
   local data_line
   #local total_line=$duration
   #local total_line_plus
   for i in `ls -t $dir/${prefix}*${ifstat_postfix}*`
   do
      con=`echo $i|awk -F _ '{a=NF-1}END{print $a}'`
      gen_final_body1 $con
      ## there are two columns data
      column=`awk '{if ($1 ~ /n\/a/); else s+=$1; if ($2 ~ /n\/a/); else t+=$2;}END{if (s < t) print 2; else print 1}' $i`
      if [ "$column" == "1" ]
      then
         g_ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $2 "(" $1 ")"}'`
      else
         g_ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $4 "(" $3 ")"}'`
      fi
      ## data to generate chart
      data_line=`expr 2 + $warm_dur`
      awk -v c=$column -v min=$ifstat_minval -v max=$ifstat_maxval -v len=$duration -v effect_data=$data_line 'BEGIN {
		i=1;j=1;
	}
	{
		if ($c >= min && $c < max && i <= len && j > effect_data) {
			printf("%d\n", $c);
			i++;
		}
		j++;
	}' $i > $tmp_dir/raw.data
      mv $data_file $tmp_dir/gen_result_tmp.data
      paste -d , $tmp_dir/gen_result_tmp.data $tmp_dir/raw.data > $data_file  
      ## data to generate table
      ministat -A $tmp_dir/raw.data | tail -n 1 | awk -v c=$con \
	'{printf("[%d, %d, %.2f, %.2f, %.2f, %.2f, %.2f],\n", c, $2, $3/1000000.0, $4/1000000.0, $5/1000000.0, $6/1000000.0, $7/1000.0)}' >> $g_table_data_file
   done
   mv $data_file $tmp_dir/gen_result_final.data
   paste -d " " $tmp_dir/gen_result_final.data $end_file > $data_file
}

cleanup()
{
   if [ -e $g_table_data_file ]
   then
      rm $g_table_data_file
   fi
   rm_tmp_dir_ifexist
}

init()
{
   init_blank_result
   init_end_column
   create_tmp_dir_ifnotexist
}

validate_input()
{
   local perf_tool=$1
   local m=1
   local m_len
   local marker
   local ret=1
   m_len=$(array_len "$marker_list" "$marker_list_sep")
   while [ $m -le $m_len ]
   do
      marker=$(array_get "$marker_list" $m "$marker_list_sep")
      if [ "$marker" == "$perf_tool" ]
      then
         ret=0
         break
      fi
      m=`expr $m + 1`
   done
   echo $ret
}

gen_html_process()
{
   if [ $# -ne 2 ]
   then
      echo "Specify dir <i|n|k>"
      exit 1
   fi

   local data_dir=$1
   local p_tool=$2

   init
   check_runtime_env
   local is_valid=$(validate_input "$p_tool")
   if [ $is_valid == 1 ]
   then
      echo "Invalid input '$p_tool'"
      log "Invalid input '$p_tool'"
      exit 1
   fi

   collect_netperf_result $data_dir $p_tool
   local html_desc=$(array_getvalue "$marker_to_htmldesc" "$p_tool" "$marker_list_sep" "$marker_to_htmldesc_sep")
   gen_view_html "$html_desc" "$g_ifstat_desc" $data_dir $p_tool

   cleanup
}
g_ifstat_desc=""

gen_view_html()
{
   local title="$1"
   local subtitle="$2"
   local indata_dir=$3
   local perf_tool=$4
   local test_start_time=`cat $status_dir/$start_time`
   local test_end_time=`cat $status_dir/$end_time`
   local perf04_tunable_option=$(get_tunable_option $perf04_corp_ip $perf04_corp_port)
   local perf03_tunable_option=$(get_tunable_option $perf03_corp_ip $perf03_corp_port)
   local perf04_sysctl_values=$(get_sysctl_option_list_values $perf04_corp_ip $perf04_corp_port $perf04_inter_ip)
   local perf03_sysctl_values=$(get_sysctl_option_list_values $perf03_corp_ip $perf03_corp_port $perf03_inter_ip)
   local top_file=""
   local out_dir=$(get_folder_from_path $indata_dir)
   local csv_chart_file=${perf_tool}${csv_chart_file_postfix}
   local csv_table_file=${perf_tool}${csv_table_file_postfix}

   for i in `ls -t $indata_dir/*${top_postfix}*`
   do
       top_file=${i##*/}
       
   done

   cat $html_header_tmpl > $final_output_file
cat << _EOF >> $final_output_file
    <script type="text/javascript">
      google.charts.load('current', {'packages':['line', 'table']});
      google.charts.setOnLoadCallback(drawChart);
      google.charts.setOnLoadCallback(drawTable);

    function drawChart() {
      var data = new google.visualization.DataTable();
      data.addColumn('number', 'Duration (sec)');
_EOF
## data for chart
   echo -e "$g_final_output_body1" >> $final_output_file
   echo "data.addRows([" >> $final_output_file
   cat $data_file >> $final_output_file
   echo "      ]);" >> $final_output_file
##
cat << EOF_ >> $final_output_file
      var options = {
        chart: {
          title: "$title",
          subtitle: "$subtitle"
        },
        width: 1500,
        height: 1000
      };

      var chart = new google.charts.Line(document.getElementById('linechart_material'));

      chart.draw(data, options);
    }

    function drawTable() {
	var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
	var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
	var data = new google.visualization.DataTable();
	data.addColumn('number', 'Connections');
        data.addColumn('number', 'Duration(s)');
        data.addColumn('number', 'Min(Gbps)');
        data.addColumn('number', 'Max(Gbps)');
	data.addColumn('number', 'Median(Gbps)');
	data.addColumn('number', 'Avg(Gbps)');
	data.addColumn('number', 'Stddev(Mbps)');
        data.addRows([
EOF_

# data for table
   cat $g_table_data_file >> $final_output_file
#
cat << E_O_F >> $final_output_file
        ]);

        var table = new google.visualization.Table(document.getElementById('table_div'));
        
        table.draw(data, options);
    }
  </script>
</head>
<body>
  <div class="container">
        <header>
            <h1>Network Performance Report</h1>
        </header>
        <div class="wrapper clearfix">
	  <div class="content">
                <section>
                    <h2>Environment</h2>
			<p>Time used for the whole run: from <b>"$test_start_time"</b> to <b>"$test_end_time"</b>.<p>
			<b>Environment for $perf04_corp_ip:$perf04_corp_port</b><br>
			<ul>
			    <li>CPU: $perf04_cpu_core</li>
			    <li>CPU details: "$perf04_cpu_info"</li>
			    <li>OS: "$perf04_uname"</li>
			    <li>tunable: "$perf04_tunable_option"</li>
			    <li>sysctl: "$perf04_sysctl_values"</li>
			    <li>static memory: "${perf04_mem}"</li>
			</ul>
		        <b>Environment for $perf03_corp_ip:$perf03_corp_port</b>
			<ul>
			    <li>CPU: $perf03_cpu_core</li>
			    <li>CPU details: "$perf03_cpu_info"</li>
			    <li>OS: "$perf03_uname"</li>
			    <li>tunable: "$perf03_tunable_option"</li>
			    <li>sysctl: "$perf03_sysctl_values"</li>
			    <li>static memory: "${perf03_mem}"</li>
			</ul>
		</section>
	  </div>
	  <div class="content">
                <section>
		    <h2>Result</h2>
		    <div><a href="$csv_table_file">Export table data to csv</a></div>
		    <div id="table_div"></div>
  		    <div><a href="$csv_chart_file">Export chart data to csv</a></div>
		    <div id="linechart_material"></div><br>
		</section>
	  </div>
E_O_F
   ## add statistics for top/vmstat if they are collected
   top_statistic=`ls -t $indata_dir/*${top_postfix}*`
   if [ "$top_statistic" != "" ]
   then
cat << EOF >> $final_output_file
          <div class="content">
                <section>
                    <h2>Statistics</h2>
EOF
	for i in `ls -t $indata_dir/*${top_postfix}*`
	do
		top_file=${i##*/}
cat << EOF >> $final_output_file
		    <div><a href="$out_dir/$top_file">$top_file</a></div>
EOF
	done
cat << EOF >> $final_output_file
		</section>
          </div>
EOF
   fi
cat << E_O_F >> $final_output_file
	</div>
	<footer>
		<p>copyright &copy; OSTC@microsoft.com</p>
	</footer>
  </div>
</body>
</html>
E_O_F
   log "Done in gen_view_html"
}

init_blank_result()
{
   if [ -e $data_file ]
   then
       rm $data_file
   fi
   local iter=1
   while [ $iter -le $duration ]
   do
       echo "[$iter" >> $data_file
       iter=`expr $iter + 1`
   done
}

init_end_column()
{
   if [ -e $end_file ]
   then
       rm $end_file
   fi
   iter=1
   while [ $iter -le $duration ]
   do
       echo "]," >> $end_file
       iter=`expr $iter + 1`
   done
}

gen_final_body1()
{
   local conn=$1
   local newline="\n"
   g_final_output_body1=${g_final_output_body1}"      data.addColumn('number', '${conn} connections');"${newline}
}

collect_netperf_result()
{
   local dir=$1
   local prefix=$2
   local con
   local column
   local data_line
   #local total_line=$duration
   #local total_line_plus
   for i in `ls -t $dir/${prefix}*${ifstat_postfix}*`
   do
      con=`echo $i|awk -F _ '{a=NF-1}END{print $a}'`
      gen_final_body1 $con
      ## there are two columns data
      column=`awk '{if ($1 ~ /n\/a/); else s+=$1; if ($2 ~ /n\/a/); else t+=$2;}END{if (s < t) print 2; else print 1}' $i`
      if [ $column == "1" ]
      then
         g_ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $2 "(" $1 ")"}'`
      else
         g_ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $4 "(" $3 ")"}'`
      fi
      ## data to generate chart
      data_line=`expr 2 + $warm_dur`
      awk -v c=$column -v min=$ifstat_minval -v max=$ifstat_maxval -v len=$duration -v effect_data=$data_line 'BEGIN {
		i=1;j=1;
	}
	{
		if ($c >= min && $c < max && i <= len && j > effect_data) {
			printf("%d\n", $c);
			i++;
		}
		j++;
	}' $i > $tmp_dir/raw.data
      mv $data_file $tmp_dir/gen_result_tmp.data
      paste -d , $tmp_dir/gen_result_tmp.data $tmp_dir/raw.data > $data_file  
      ## data to generate table
      ministat -A $tmp_dir/raw.data | tail -n 1 | awk -v c=$con \
	'{printf("[%d, %d, %.2f, %.2f, %.2f, %.2f, %.2f],\n", c, $2, $3/1000000.0, $4/1000000.0, $5/1000000.0, $6/1000000.0, $7/1000.0)}' >> $g_table_data_file
   done
   mv $data_file $tmp_dir/gen_result_final.data
   paste -d " " $tmp_dir/gen_result_final.data $end_file > $data_file
}

cleanup()
{
   if [ -e $g_table_data_file ]
   then
      rm $g_table_data_file
   fi
   rm_tmp_dir_ifexist
}

init()
{
   init_blank_result
   init_end_column
   create_tmp_dir_ifnotexist
}

validate_input()
{
   local perf_tool=$1
   local m=1
   local m_len
   local marker
   local ret=1
   m_len=$(array_len "$marker_list" "$marker_list_sep")
   while [ $m -le $m_len ]
   do
      marker=$(array_get "$marker_list" $m "$marker_list_sep")
      if [ "$marker" == "$perf_tool" ]
      then
         ret=0
         break
      fi
      m=`expr $m + 1`
   done
   echo $ret
}

gen_html_process()
{
   if [ $# -ne 2 ]
   then
      echo "Specify dir <i|n|k>"
      exit 1
   fi

   local data_dir=$1
   local p_tool=$2

   init
   check_runtime_env
   local is_valid=$(validate_input "$p_tool")
   if [ $is_valid == 1 ]
   then
      echo "Invalid input '$p_tool'"
      log "Invalid input '$p_tool'"
      exit 1
   fi

   collect_netperf_result $data_dir $p_tool
   local html_desc=$(array_getvalue "$marker_to_htmldesc" "$p_tool" "$marker_list_sep" "$marker_to_htmldesc_sep")
   gen_view_html "$html_desc" "$g_ifstat_desc" $data_dir $p_tool

   cleanup
}
############### end of generate html ####

############### gen csv tables for netperf ##########
gen_netperf_csv()
{
   local prefix=$1
   local perf_tool=$2
   local tmp_dir=$3
   local con
   local column
   local data_line
   local first_row=""
   local tmp_tbl_file=$tmp_dir/tmp_tbl_file.data
   local csv_one_col_file=${perf_tool}_col_csv.data
   local csv_tmp_file=${perf_tool}_csv.data
   local csv_chart_file=${perf_tool}${csv_chart_file_postfix}
   local csv_table_file=${perf_tool}${csv_table_file_postfix}
   if [ -e $csv_tmp_file ]
   then
     rm $csv_tmp_file
   fi

   if [ -e $csv_chart_file ]
   then
     rm $csv_chart_file
   fi
   if [ -e $csv_table_file ]
   then
     rm $csv_table_file
   fi
   for i in `ls -t $dir/${prefix}*${ifstat_postfix}*`
   do
      con=`echo $i|awk -F _ '{a=NF-1}END{print $a}'`
      if [ "${first_row}" != "" ]
      then
         first_row=${first_row}", ${con} connections"
      else
         first_row="${con} connections"
      fi
      ## there are two columns data
      column=`awk '{if ($1 ~ /n\/a/); else s+=$1; if ($2 ~ /n\/a/); else t+=$2;}END{if (s < t) print 2; else print 1}' $i`
      if [ $column == "1" ]
      then
         ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $2 "(" $1 ")"}'`
      else
         ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $4 "(" $3 ")"}'`
      fi
      ## data to generate chart
      let data_line=2+$warm_dur > /dev/null
      awk -v c=$column -v min=$ifstat_minval -v max=$ifstat_maxval -v len=$duration -v effect_data=$data_line 'BEGIN {
		i=1;j=1;
	}
	{
		if ($c >= min && $c < max && i <= len && j > effect_data) {
			printf("%d\n", $c);
			i++;
		}
		j++;
	}' $i > $tmp_dir/$csv_one_col_file
      if [ -e $csv_tmp_file ]
      then
         mv $csv_tmp_file $tmp_dir/gen_csv_result.data
         paste -d , $tmp_dir/gen_csv_result.data $tmp_dir/$csv_one_col_file > $csv_tmp_file
      else
         cp $tmp_dir/$csv_one_col_file $csv_tmp_file
      fi
      
      ## data to generate table
      ministat -A $tmp_dir/$csv_one_col_file | tail -n 1| awk -v c=$con '{printf("%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f\n", c, $2, $3/1000000.0, $4/1000000.0, $5/1000000.0, $6/1000000.0, $7/1000.0)}' >> $tmp_tbl_file
   done
   echo $first_row > $csv_chart_file
   cat $csv_tmp_file >> $csv_chart_file
   echo "Connections,Duration(s),Min(Gbps),Max(Gbps),Median(Gbps),Avg(Gbps),Stddev(Mbps)" > $csv_table_file
   cat $tmp_tbl_file >> $csv_table_file

   rm $tmp_tbl_file  
}

gen_iperf_csv()
{
   local con
   local header
   local iperf_prefix=$1
   local perf_tool=$2
   local tmp_dir=$3
   local tmp_tbl_file=$tmp_dir/tmp_tbl_file.data
   local csv_one_col_file=${perf_tool}_col_csv.data
   local csv_tmp_file=${perf_tool}_csv.data
   local first_row=""
   local csv_chart_file=${perf_tool}${csv_chart_file_postfix}
   local csv_table_file=${perf_tool}${csv_table_file_postfix}
   if [ -e $csv_tmp_file ]
   then
     rm $csv_tmp_file
   fi
   if [ -e $csv_chart_file ]
   then
     rm $csv_chart_file
   fi
   if [ -e $csv_table_file ]
   then
     rm $csv_table_file
   fi
   for i in `ls -t $dir/${iperf_prefix}*${iperf_postfix}`
   do
      con=`echo $i|awk -F _ '{a=NF-1}END{print $a}'`
      if [ "${first_row}" != "" ]
      then
         first_row=${first_row}", ${con} connections"
      else
         first_row="${con} connections"
      fi
      ## data to generate chart
      if [ $con == 1 ]
      then
         let header=$duration+3 > /dev/null
         head -n $header $i|tail -n $duration| \
            awk '{if (match($8, "Mbits")) printf ("%.3f\n", $7/1000); else if (match($8, "Gbits")) print $7;}' > $tmp_dir/$csv_one_col_file
      else
         grep "SUM" $i|head -n $duration | \
            awk '{if (match($7, "Mbits")) printf ("%.3f\n", $6/1000); else if (match($7, "Gbits")) print $6;}' > $tmp_dir/$csv_one_col_file
      fi

      if [ -e $csv_tmp_file ]
      then
         mv $csv_tmp_file $tmp_dir/gen_csv_result.data
         paste -d , $tmp_dir/gen_csv_result.data $tmp_dir/$csv_one_col_file > $csv_tmp_file
      else
         cp $tmp_dir/$csv_one_col_file $csv_tmp_file
      fi

      ## data to generate table
      ministat -A $tmp_dir/$csv_one_col_file | tail -n 1 | awk -v c=$con '{printf("%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f\n", c, $2, $3/1024/1024, $4/1024/1024, $5/1024/1024, $6/1024/1024, $7/1024)}' >> $tmp_tbl_file
   done
   echo $first_row > $csv_chart_file
   cat $csv_tmp_file >> $csv_chart_file
   echo "Connections,Duration(s),Min(Gbps),Max(Gbps),Median(Gbps),Avg(Gbps),Stddev(Mbps)" > $csv_table_file
   cat $tmp_tbl_file >> $csv_table_file

   rm $tmp_tbl_file  
}

gen_csv_process()
{
if [ $# -ne 2 ]
then
   echo "Specify dir <i|n>"
   exit 1
fi

local dir=$1
local perf_tool=$2
local tmp_dir="gen_csv_tmp"
  if [ ! -d $tmp_dir ]
  then
    mkdir $tmp_dir
  fi
perf_prefix=$(array_getvalue "$marker_to_prefix" "$perf_tool" "$marker_list_sep" "$marker_to_prefix_sep")
gen_netperf_csv $perf_prefix $perf_tool $tmp_dir

  if [ -d $tmp_dir ]
  then
    rm -rf $tmp_dir
  fi
}

upload_result_to_cloud()
{
  local newdata=`find $result_path -type d -name "[0-9]*"|sort -r |head -n 1`
  scp -r $newdata $cloud_user@${cloud_server}:${result_path}/
  log "scp $newdata $cloud_user@${cloud_server}:${result_path}"
  scp replace.py $cloud_user@${cloud_server}:${result_path}
  ssh $cloud_user@${cloud_server} python replace.py
  log "ssh $cloud_user@${cloud_server} python replace.py"
}
