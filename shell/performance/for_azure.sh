#!/bin/sh
if [ "$__PERF_ENV__" != "1" ]
then
   ## This file will invoke functions defined in perf_env.sh, e.g. log
   echo "Please run perf_env.sh before this script"
fi
azure_cli_login() {
   log "azure login --username b8a77132-6ee7-481a-8a29-22797c849e1a --password ICUI4CU --service-principal --tenant 72f988bf-86f1-41af-91ab-2d7cd011db47"
   azure login --username b8a77132-6ee7-481a-8a29-22797c849e1a --password ICUI4CU --service-principal --tenant 72f988bf-86f1-41af-91ab-2d7cd011db47
}

azure_cli_arm() {
   log "azure config mode arm"
   azure config mode arm
}

azure_cli_asm() {
   log "azure config mode arm"
   azure config mode arm
}

valid_exist_resgroup() {
   local resGrp=$1
   local find_line=`azure group list|grep $resGrp|wc -l|awk '{print $1}'`
   if [ "$find_line" == "0" ]
   then
      echo "1"
   else
      echo "0"
   fi
}

valid_exist_vm() {
   local resGrp=$1
   local vm=$2
   local find_line=`azure vm list $resGrp|grep $vm|wc -l|awk '{print $1}'`
   if [ "$find_line" == "0" ]
   then
      echo "1"
   else
      echo "0"
   fi
}

vm_instance_view_status() {
   local resGrp=$1
   local vm=$2
   log "azure vm get-instance-view $resGrp $vm --json | python -c \"import json,sys;obj=json.load(sys.stdin); print(obj['instanceView']['statuses'][1]['code']);\"|awk -F / '{print $2}'"
   local res=`azure vm get-instance-view $resGrp $vm --json | python -c "import json,sys;obj=json.load(sys.stdin); print(obj['instanceView']['statuses'][1]['code']);"|awk -F / '{print $2}'`
   echo "$res"
}

stop_exist_vm() {

}


