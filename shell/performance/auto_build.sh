#!/bin/sh
. perf_env.sh

KERN_CONF=GENERIC-NODEBUG
login_and_build() {
   local prefix=`date +%Y%m%d%H%M%S`
   local build_log_file=${prefix}_build.log
   local install_log_file=${prefix}_install.log
   local build_log_path=$tmp_dir/$build_log_file
   local install_log_path=$tmp_dir/$install_log_file
   ssh root@$build_machine_ip "cd $src_folder; svn up; make -j8 buildkernel KERNCONF=$KERN_CONF" |tee $build_log_path
   ## check build errors
   build_proc_marker=`grep "Kernel build for" $build_log_path|wc -l|awk '{print $1}'`
   if [ $build_proc_marker == 2 ]
   then
      log "build passed"
   else
      log "build error occurs! see $build_log_path"
      return
   fi
   ssh root@$build_machine_ip -p $build_machine_port "cd $src_folder; make -j8 installkernel KERNCONF=$KERN_CONF"|tee $install_log_path
   ## check install errors
   ssh root@$build_machine_ip -p $build_machine_port "cd /boot; tar zcvf $kernel_zip_file kernel"
   scp -P $build_machine_port root@$build_machine_ip:/boot/$kernel_zip_file .
   cp $kernel_zip_file $kernel_bak_folder/${prefix}${kernel_zip_file}
}

distribute_kernel_and_reboot() {
   if [ -e $kernel_zip_file ]
   then
   	scp -P $perf03_corp_port $kernel_zip_file root@$perf03_corp_ip:/boot/
   	ssh root@$perf03_corp_ip -p $perf03_corp_port "cd /boot; tar zxvf $kernel_zip_file"
   	scp -P $perf04_corp_port $kernel_zip_file root@$perf04_corp_ip:/boot/
   	ssh root@$perf04_corp_ip -p $perf04_corp_port "cd /boot; tar zxvf $kernel_zip_file"
	reboot_perf03
	reboot_perf04
	if [ "$storage_remote_ip" != "$perf03_corp_ip" ] && 
           [ "$storage_remote_ip" != "$perf04_corp_ip" ] &&
           [ "$storage_remote_port" != "$perf03_corp_port" ] &&
           [ "$storage_remote_port" != "$perf04_corp_port" ]
	then
		scp -P $storage_remote_port $kernel_zip_file root@$storage_remote_ip:/boot/
		ssh root@$storage_remote_ip -p $storage_remote_port "cd /boot; tar zxvf $kernel_zip_file"
		reboot_storage_server
	fi
   else
	log "Cannot find $kernel_zip_file and cannot distribute it to test VMs"
   fi
}

create_tmp_dir_ifnotexist
create_kernel_bak_ifnotexist
if [ -e ${kernel_zip_file} ]
then
   rm ${kernel_zip_file}
fi
login_and_build
distribute_kernel_and_reboot
