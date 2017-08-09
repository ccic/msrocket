#!/bin/sh
. jenkins_server.sh

if [ "$__SERVER_ENV__" != "1" ]
then
   ## This file will override some variables defined in server_env.sh
   echo "Please run server_env.sh before this script"
fi
if [ "$__PERF_ENV__" != "1" ]
then
   ## This file will invoke functions defined in perf_env.sh, e.g. log
   echo "Please run perf_env.sh before this script"
fi

config_log_level()
{
   log_level=$1
}

extract_alias()
{
    local mailbox=$1
    local len=$(array_len "$mailbox" ",")
    local m=1
    local item
    local person_alias
    local ret=""
    while [ $m -le $len ]
    do
	item=$(array_get "$mailbox" $m ",")
	person_alias=`echo $item|awk -F @ '{print $1}'`
	ret="$ret"$person_alias
	m=`expr $m + 1`
    done
    echo $ret
}

job_env_variables()
{
   if [ "${ReceiverList}" != "" ]
   then
	g_receivers_list=${ReceiverList}
   fi

   if [ "${GitRepo}" != "" ]
   then
	g_gitrepo=${GitRepo}
   fi

   if [ "${GitBranch}" != "" ]
   then
	g_gitbranch=${GitBranch}
   fi

   if [ "${StorageCases}" != "" ] && [ "${StorageCases}" != "NA" ]
   then
	g_storagecases=${StorageCases}
   fi

   if [ "${NetperfCases}" != "" ] && [ "${NetperfCases}" != "NA" ]
   then
	g_netperfcases=${NetperfCases}
   fi
   ######## get the variables set from Jenkins #######
   if [ "${j_remote_sender_ip}" != "" ]
   then
	perf04_corp_ip=${j_remote_sender_ip}
   fi
   if [ "${j_remote_receiver_ip}" != "" ]
   then
	perf03_corp_ip=${j_remote_receiver_ip}
   fi

   if [ "${j_internal_sender_ip}" != "" ]
   then
	perf04_inter_ip=${j_internal_sender_ip}
   fi
   if [ "${j_internal_receiver_ip}" != "" ]
   then
	perf03_inter_ip=${j_internal_receiver_ip}
   fi

   if [ "${j_connection_list}" != "" ]
   then
	connection_iter="${j_connection_list}"
   fi
   if [ "${j_internal_nic}" != "" ]
   then
	internal_nic="${j_internal_nic}"
   fi
   if [ "${j_storage_remote_ip}" != "" ]
   then
	storage_remote_ip=${j_storage_remote_ip}
   fi
   if [ "${j_storage_remote_port}" != "" ]
   then
	storage_remote_port=${j_storage_remote_port}
   fi
   if [ "${j_fio_iodepth_list}" != "" ]
   then
	fio_iodepth_list=${j_fio_iodepth_list}
   fi
   if [ "${j_disk_part}" != "" ]
   then
	disk_part=${j_disk_part}
   fi
   if [ "${j_result_path}" != "" ]
   then
	result_path=${j_result_path}
   fi
   if [ "${j_webserver_port}" != "" ]
   then
	webserver_port=${j_webserver_port}
   fi
   need_build_kernel=${j_need_build_kernel}
   need_fetch_nightly_report=${j_need_fetch_nightly_report}
   
   storage_test_user=${j_storage_test_user}
   #fio_engine=${j_fio_engine}
   build_machine_ip=${j_build_machine_ip}
   build_machine_port=${j_build_machine_port}
   checkout_user=${j_checkout_user}
   build_user=${j_build_user}
   BUILD_OPTION=${j_BUILD_OPTION}
   build_folder=${j_build_folder}
   nightly_jenkins_admin=${j_nightly_jenkins_admin}
   nightly_jenkins_remote_ip=${j_nightly_jenkins_remote_ip}
   nightly_jenkins_remote_port=${j_nightly_jenkins_remote_port}
   nightly_jenkins_report_dir=${j_nightly_jenkins_report_dir}
   webserver_port=${j_webserver_port}
   choose_NUMA=${j_choose_NUMA}
   need_reboot=${j_need_reboot}
   auto_create_part_4_sysbench=${j_auto_part}

   receivers_list=${g_receivers_list} ## modify the default value according to Jenkins
   user_aliases=$(extract_alias ${receivers_list})
   log "Job name:                            [$JOB_NAME]"
   log "********************************************************"
   log "need_build_kernel:                   '$need_build_kernel'"
   log "need_fetch_nightly:                  '$need_fetch_nightly_report'"
   log "perf04_corp_ip(sender):              '$perf04_corp_ip'"
   log "perf04_inter_ip:                     '$perf04_inter_ip'"
   log "perf03_corp_ip(receiver):            '$perf03_corp_ip'"
   log "perf03_inter_ip:                     '$perf03_inter_ip'"
   log "internal_nic:                        '$internal_nic'"
   log "connection_iter:                     '$connection_iter'"
   log "storage_remote_ip:                   '$storage_remote_ip'"
   log "storage_remote_port:                 '$storage_remote_port'"
   log "storage_test_user:                   '$storage_test_user'"
   log "need_reboot:                         '$need_reboot'"
   log "disk_part:                           '$disk_part'"
   log "auto_create_part_4_sysbench:         '$auto_create_part_4_sysbench'"
   log "fio_iodepth_list:                    '$fio_iodepth_list'"
   log "StorageCases:                        '$g_storagecases'"
   log "NetperfCases:                        '$g_netperfcases'"
   log "build_machine_ip:                    '$build_machine_ip'"
   log "build_machine_port:                  '$build_machine_port'"
   log "checkout_user:                       '$checkout_user'"
   log "build_user:                          '$build_user'"
   log "build_option:                        '$BUILD_OPTION'"
   log "build_folder:                        '$build_folder'"
   log "nightly_jenkins_admin:               '$nightly_jenkins_admin'"
   log "nightly_jenkins_remote_ip:           '$nightly_jenkins_remote_ip'"
   log "nightly_jenkins_remote_port:         '$nightly_jenkins_remote_port'"
   log "nightly_jenkins_report_dir:          '$nightly_jenkins_report_dir'"
   log "result path:                         '$result_path'"
   log "webserver port:                      '$webserver_port'"
   log "choose_NUMA:                         '$choose_NUMA'"
   log "git repo:                            '$g_gitrepo'"
   log "git branch:                          '$g_gitbranch'"
   log "Receiver:                            '$receivers_list'"
   log "user alias:                          '$user_aliases'"
   log "********************************************************"
}

checkout_and_build()
{
   local git_repo=$1
   local git_branch=$2

   create_tmp_dir_ifnotexist

   local post_fix=`date +%Y%m%d%H%M%S`
   local local_repo
   local prefix
   if [ "$user_aliases" != "" ]
   then
       prefix=${user_aliases}
   else
       prefix=mybuild
   fi

   local_repo=${prefix}_${post_fix}
   local build_log_file=$tmp_dir/${local_repo}_build.log
   local install_log_file=$tmp_dir/${local_repo}_install.log
   local build_status
   local build_folder_path=$build_folder/$local_repo

   log "start to checkout_and_build"
   log "ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} cd /home/${checkout_user}; rm -rf $build_folder"
   ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} "cd /home/${checkout_user};rm -rf $build_folder"

   log "ssh ${checkout_user}@${build_machine_ip} -p ${build_machine_port} mkdir -p $build_folder"
   ssh ${checkout_user}@${build_machine_ip} -p ${build_machine_port} "mkdir -p $build_folder"

   log "ssh ${checkout_user}@${build_machine_ip} -p ${build_machine_port} cd $build_folder; git clone -b $git_branch --single-branch $git_repo $local_repo"
   ssh ${checkout_user}@${build_machine_ip} -p ${build_machine_port} "cd $build_folder; git clone -b $git_branch --single-branch $git_repo $local_repo"
   
   log "ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} cd /home/${checkout_user};cd $build_folder_path; make -j6 buildkernel KERNCONF=$BUILD_OPTION"
   ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} "cd /home/${checkout_user};cd $build_folder_path;make -j6 buildkernel KERNCONF=$BUILD_OPTION" | tee $build_log_file

   build_status=`grep "Kernel build for" $build_log_file|wc -l|awk '{print $1}'`
   if [ $build_status == 2 ]
   then
      log "build passed"
   else
      log "build error occurs! see $build_log_file"
      echo 1
      return
   fi

   log "ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} cd /home/${checkout_user};cd $build_folder_path;make installkernel KERNCONF=$BUILD_OPTION"
   ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} "cd /home/${checkout_user};cd $build_folder_path;make installkernel KERNCONF=$BUILD_OPTION" | tee $install_log_file
   
   log "ssh ${build_user}@${build_machine_ip} -p $build_machine_port cd /boot; tar zcvf $kernel_zip_file kernel"
   ssh ${build_user}@${build_machine_ip} -p $build_machine_port "cd /boot; tar zcvf $kernel_zip_file kernel"

   log "scp -P $build_machine_port ${build_user}@${build_machine_ip}:/boot/$kernel_zip_file ."
   scp -P $build_machine_port ${build_user}@${build_machine_ip}:/boot/$kernel_zip_file .

   if [ ! -e $kernel_zip_file ]
   then
      log "Error: cannot find the $kernel_zip_file"
      return
   fi
   create_kernel_bak_ifnotexist
   log "cp $kernel_zip_file $kernel_bak_folder/${post_fix}${kernel_zip_file}"
   cp $kernel_zip_file $kernel_bak_folder/${post_fix}${kernel_zip_file}
   log "end of checkout_and_build"
}

distribute_kernel_for_test() {
	log "start at distribute_kernel_for_test"
	if [ $g_storagecases != "" ]
	then
	   distribute_kernel $kernel_zip_file $storage_remote_ip $storage_remote_port root
	   reboot_machine $storage_remote_ip $storage_remote_port
	   log "sleep 120"
	   sleep 120
	fi
	log "end at distribute_kernel_for_test"
}

quick_build_and_copy_kernel()
{
   create_tmp_dir_ifnotexist

   local post_fix=$1
   local local_repo=mybuild_${post_fix}
   local build_log_file=$tmp_dir/${local_repo}_build.log
   local install_log_file=$tmp_dir/${local_repo}_install.log
   local build_status

   log "ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} cd $local_repo;make -j6 -DKERNFAST buildkernel KERNCONF=$BUILD_OPTION"
   ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} "cd /home/${checkout_user};cd $local_repo;make -j6 -DKERNFAST buildkernel KERNCONF=$BUILD_OPTION" | tee $build_log_file

   build_status=`grep "Kernel build for" $build_log_file|wc -l|awk '{print $1}'`
   if [ $build_status == 2 ]
   then
      log "build passed"
   else
      log "build error occurs! see $build_log_file"
      return
   fi

   log "ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} cd /home/${checkout_user};cd $local_repo;make installkernel KERNCONF=$BUILD_OPTION"
   ssh ${build_user}@${build_machine_ip} -p ${build_machine_port} "cd /home/${checkout_user};cd $local_repo;make installkernel KERNCONF=$BUILD_OPTION" | tee $install_log_file
   
   log "ssh ${build_user}@${build_machine_ip} -p $build_machine_port cd /boot; tar zcvf $kernel_zip_file kernel"
   ssh ${build_user}@${build_machine_ip} -p $build_machine_port "cd /boot; tar zcvf $kernel_zip_file kernel"

   log "scp -P $build_machine_port ${build_user}@${build_machine_ip}:/boot/$kernel_zip_file ."
   scp -P $build_machine_port ${build_user}@${build_machine_ip}:/boot/$kernel_zip_file .

   if [ ! -e $kernel_zip_file ]
   then
      log "Error: cannot find the $kernel_zip_file"
      return
   fi
   create_kernel_bak_ifnotexist
   log "cp $kernel_zip_file $kernel_bak_folder/${post_fix}${kernel_zip_file}"
   cp $kernel_zip_file $kernel_bak_folder/${post_fix}${kernel_zip_file}
}

import_latest_nightly_result()
{
   local nightly_jenkins_server=$1
   local nightly_jenkins_port=$2
   local nightly_jenkins_user=$3
   local nightly_result_folder=$4
   log "ssh ${nightly_jenkins_user}@${nightly_jenkins_server} -p ${nightly_jenkins_port} ls -t $nightly_result_folder | head -n 1"
   latest_nightly_folder=`ssh ${nightly_jenkins_user}@${nightly_jenkins_server} -p ${nightly_jenkins_port} ls -t $nightly_result_folder | head -n 1`
   local is_valid=`echo "$latest_nightly_folder" | awk '{if ($1 ~ /^[0-9]+$/) {print 1;} else {print 0;} }'`
   if [ "$is_valid" == "1" ]
   then
	log "scp -r -P ${nightly_jenkins_port} ${nightly_jenkins_user}@${nightly_jenkins_server}:${nightly_result_folder}/${latest_nightly_folder} $result_path/"
	scp -r -P ${nightly_jenkins_port} ${nightly_jenkins_user}@${nightly_jenkins_server}:${nightly_result_folder}/${latest_nightly_folder} $result_path/
   fi
}

disable_all_running_drv() {
	local m_len=$(array_len "$drv_list" "$drv_list_sep")
	local m=1
	local drv_prefix
	local run_drv
	while [ $m -le $m_len ]
	do
		drv_prefix=$(array_get "$drv_list" $m "$drv_list_sep")
		eval run_${drv_prefix}="no"
		m=`expr $m + 1`
	done
}

set_running_drv() {
	local m_len
	local m=1
	local drv
	if [ "$g_storagecases" != "" ]
	then
	   m_len=$(array_len "$g_storagecases" ":")
	   while [ $m -le $m_len ]
	   do
		drv=$(array_get "$g_storagecases" $m ":")
		log "expected running drv: $drv"
		eval run_${drv}="yes"
		m=`expr $m + 1`
	   done
	fi

	m=1
	if [ "$g_netperfcases" != "" ]
	then
	   m_len=$(array_len "$g_netperfcases" ":")
	   while [ $m -le $m_len ]
	   do
		drv=$(array_get "$g_netperfcases" $m ":")
		log "expected running drv: $drv"
		eval run_${drv}="yes"
		m=`expr $m + 1`
	   done
	fi
}

run_all_selected_services()
{
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
	log "start at run_all_selected_services"
        #######################################################
	#### run each test driver according to driver list ####
	while [ $m -le $m_len ]
	do
		drv_prefix=$(array_get "$drv_list" $m "$drv_list_sep")
		log "driver prefix: $drv_prefix"
		run_drv=$(derefer_2vars "run_" $drv_prefix)
		log "run_${drv_prefix}: $run_drv"
		if [ "$run_drv" == "yes" ]
		then
			echo "run $drv_prefix"
			log "run $drv_prefix"
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

	log "end at run_all_selected_services"

	if [ $has_drv_run == 1 ]
	then
		. gen_summary.sh
		mv $summary_html_file $curr_result_dir/
	fi

	local mail_tag=`echo $result_path|awk -F / '{print $NF}'`
        if [ $? -eq 0 ]
        then
	  send_mail $curr_result_dir $curr_dir $mail_tag $webserver_port
	  output_state_msg "send_mail"
        else
          echo "fail to generate html file"
        fi
}

test_env() {
	echo "$result_path"
}

clean_history_report()
{
	log "rm -rf $result_path/*"
	rm -rf $result_path/*
}

prepare_result_folder()
{
	curr_dir=$result_dir			## global var
	curr_result_dir=$result_path/$curr_dir	## global var
	log "mkdir -p $curr_result_dir"
	mkdir -p $curr_result_dir

	log "cp -r $css_folder $result_path/"
	cp -r $css_folder $result_path/
}
