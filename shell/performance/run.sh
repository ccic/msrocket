#!/bin/sh
base=`dirname $0`
## Prerequisite:
##   install ifstat, netperf on test machines
##   auto login configuration
## Assumption:
##   There is two NICs
##   internal ip: 192.168.XX.XX
. ${base}/perf_env.sh

main_proc()
{
	#os_para_config
	#output_state_msg "os_para_config"
	## configure internal ip
	if [ "$auto_build" == "yes" ]
	then
		sh ${base}/auto_build.sh
		if [ -e ${kernel_zip_file} ]
		then
			sleep 180 ## sleep for 2 mins and wait for boot successful
		else
			echo "There is no ${kernel_zip_file}, suppose build failed"
			log "There is no ${kernel_zip_file}, suppose build failed"
			return
		fi
	fi

	cp -r $css_folder $result_path/

	local has_drv_run=0
	local m_len=$(array_len "$drv_list" "$drv_list_sep")
	log "driver list length: $m_len"
	local m=1
	local run_drv
	local drv_prefix
	local config_char
	local cmd_list
	local cmd
	local n=1
	local n_len
        #######################################################
	#### run each test driver according to driver list ####
	while [ $m -le $m_len ]
	do
		drv_prefix=$(array_get "$drv_list" $m "$drv_list_sep")
		log "driver[$m] prefix: $drv_prefix"
		run_drv=$(derefer_2vars "run_" $drv_prefix)
		log "run_${drv_prefix}: $run_drv"
		if [ "$run_drv" == "yes" ]
		then
			if [ -e ${base}/$drv_config_folder/$drv_prefix ]
			then
				cmd_list=""
				while read line
				do
					if [ "$line" == "" ]
					then
						continue
					fi

					config_char=`echo "$line"|cut -c 1`
					if [ "$config_char" == "#" ]
					then
						continue
					else
						has_drv_run=1
						if [ "$cmd_list" == "" ]
						then
							cmd_list="${line}"
						else
							cmd_list=$cmd_list"|${line}"
						fi
					fi
				done < ${base}/$drv_config_folder/$drv_prefix

				n_len=$(array_len "$cmd_list" "|")
				n=1
				while [ $n -le $n_len ]
				do
					cmd=$(array_get "$cmd_list" $n "|")
					log "[eval $cmd]"
					eval "$cmd"
					n=`expr $n + 1`
				done
			else
				log "${base}/$drv_config_folder/$drv_prefix does not exist!"
			fi
		fi
		m=`expr $m + 1`
	done

	if [ $has_drv_run == 1 ]
	then
		sh ${base}/gen_summary.sh
		mv $summary_html_file $curr_result_dir/
	fi

        if [ $? -eq 0 ]
        then
	  send_mail $curr_result_dir $curr_dir "BIS" 80
	  output_state_msg "send_mail"
          upload_result_to_cloud
        else
          echo "fail to generate html file"
        fi
}

check_env()
{
	echo $perf04_corp_ip
	echo $perf04_inter_ip
	echo $perf03_corp_ip
	echo $perf03_inter_ip
	echo $duration
	echo $tcpstream_pkg
	echo $config_ip_sh
	echo $tcpstream
	echo $netperf_sh
	echo $ssh_id_path
	for i in $(echo $connection_iter)
	do
		echo $i
	done
	check_runtime_env
	echo "$perf04_cpu_core"
	echo "$perf04_uname"
}

curr_dir=$result_dir
curr_result_dir=$result_path/$curr_dir
mkdir -p $curr_result_dir
log_level=2
main_proc
