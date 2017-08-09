#!/bin/sh
if [ "$__SERVER_ENV__" == "1" ]
then
   return
fi
__SERVER_ENV__=1
## This file defines some critial variables for which machine is running this test, which test should be run, who will receive this report
## For temporarily test, please modify those variables.
config_internal_ip="yes"
choose_NUMA="0"  ## "0" means running on NUMA 0, "1" means running on NUMA 1, "no" means disabled NUMA consideration
need_reboot="yes"
disk_part=da1
internal_nic="hn1"
fio_engine=posixaio
build_machine_ip=10.156.76.116 ## %% perf01: 10.156.76.34, perf04: 10.156.76.102
build_machine_port=22
## perf04 --> perf03
perf04_corp_ip=10.156.76.116 ## %% perf02: 10.156.76.114, perf04: 10.156.76.102
perf04_corp_port=22
perf04_inter_ip=192.168.0.44 ## %% inter perf02: 192.168.0.20, inter perf04: 192.168.0.44
perf04_inter_port=22
perf04_dummy_server_ip=10.156.76.119 ## dummy server on perf04
perf04_dummy_server_port=22

perf03_corp_ip=10.156.76.123 ## %% perf01: 10.156.76.34, perf03: 10.156.76.97
perf03_corp_port=22
perf03_inter_ip=192.168.0.33 ## %% inter perf01: 192.168.0.10, inter perf03: 192.168.0.33
perf03_inter_port=22
perf03_dummy_server_ip=10.156.76.48 ## dummy server on perf03
perf03_dummy_server_port=22

storage_remote_ip=$perf04_corp_ip
storage_remote_port=22
storage_dummy_server_ip=$perf04_dummy_server_ip
storage_dummy_server_port=22
## perf03 --> perf04
## reverse the sender and receiver for NUMA node preference
#perf04_corp_ip=10.156.76.97 ## %% perf02: 10.156.76.114, perf04: 10.156.76.102
#perf04_inter_ip=192.168.0.33 ## %% inter perf02: 192.168.0.20, inter perf04: 192.168.0.44
#perf04_dummy_server_ip=10.156.76.48 ## dummy server on perf03

#perf03_corp_ip=10.156.76.102 ## %% perf01: 10.156.76.34, perf03: 10.156.76.97
#perf03_inter_ip=192.168.0.44 ## %% inter perf01: 192.168.0.10, inter perf03: 192.168.0.33
#perf03_dummy_server_ip=10.156.76.87 ## dummy server on perf04

#fio_remote_ip=$perf03_corp_ip ## %% perf01: 10.156.76.34, perf04: 10.156.76.102
#fio_dummy_server_ip=$perf03_dummy_server_ip

#sysbench_remote_ip=$perf03_corp_ip ##
#sysbench_dummy_server_ip=$perf03_dummy_server_ip

auto_build=yes ## %%
run_netperf=no ## %%
run_kqperf=yes ## %%
run_ntttcp=no ## only for LIS
run_fio=yes ## %%
run_sysbench=no ## %%
run_sio=yes ##
run_iperf=no ## %%

## the local server fail to send mail for unknow reason,
## so I used another VM to send mail.
#mailclient="10.156.76.70"
mailhost="sh-ostc-th51dup"
mailserverport="8181"
mailvm="hz_FreeBSD10.3_publish_image"

use_mailclient=yes
receivers_list="honzhan@microsoft.com,decui@microsoft.com,kyliel@microsoft.com,jinmiao@microsoft.com,yaqia@microsoft.com,v-hoxian@microsoft.com"
connection_iter="1 2 4 8 16 32 64 128 256 512 1024 2048 4096 5120"

## cloud server
cloud_server="52.187.125.181"
cloud_user="honzhan"
