#!/bin/sh
## result folder ##
if [ "$__PERF_ENV__" != "1" ];then
   echo "Please run perf_env.sh first before this script"
fi

## all of those environments should be set through Jenkins parameters
## Please do not set through this function.
set_internal_env() {
result_path=~/NginxRoot/SelfPerf
webserver_port=8282
## internal settings ##
build_machine_ip=10.156.76.99
build_machine_port=22
checkout_user=test
build_user=root

storage_remote_ip=10.156.76.102
storage_remote_port=22
storage_test_user=test
disk_part=da1
fio_engine=posixaio

BUILD_OPTION=GENERIC-NODEBUG
build_folder=jenkins_selfservice

nightly_jenkins_remote_ip=10.156.76.127
nightly_jenkins_remote_port=22
nightly_jenkins_admin=honzhan
nightly_jenkins_report_dir=~/NginxRoot/Perf

need_build_kernel=yes
need_fetch_nightly_report=yes
}

