#!/bin/sh
. perf_env.sh
. for_jenkins.sh

for_test()
{
	job_env_variables

	prepare_result_folder

	checkout_and_build $g_gitrepo $g_gitbranch
	#quick_build_and_copy_kernel 20160706102349

	if [ ! -e $kernel_zip_file ]
	then
		log "Stop the following test for build failure"
		exit 1
	else
		log "Successfully build kernel"
	fi

	distribute_kernel_for_test
}

main() {
	job_env_variables

	if [ "$need_fetch_nightly_report" == "yes" ]
	then
		## clean history report because it requires to fetch nightly report for comparison
		clean_history_report
	fi

	prepare_result_folder

	if [ "$need_build_kernel" == "yes" ]
	then
		checkout_and_build $g_gitrepo $g_gitbranch
		if [ ! -e $kernel_zip_file ]
		then
			log "Stop the following test for build failure"
			exit 1
		fi
		distribute_kernel_for_test
	fi

	disable_all_running_drv

	set_running_drv

	if [ "$need_fetch_nightly_report" == "yes" ]
	then
		import_latest_nightly_result ${nightly_jenkins_remote_ip} ${nightly_jenkins_remote_port} ${nightly_jenkins_admin} ${nightly_jenkins_report_dir}
	fi

	run_all_selected_services
}

config_log_level 2
main
#job_env_variables
