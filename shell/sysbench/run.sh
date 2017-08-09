#!/bin/sh
. env.sh

storage_engine_list="innodb bdb heap ndbcluster federated"

log()
{
    local msg=$1
    if [ $log_level -ge 2 ]
    then
        logger -t $LOG_PREFIX $msg
    fi
}

prepare()
{
    local cmd="sysbench $TABLE_CMD prepare"
    log "eval \"$cmd\""
    eval "$cmd"
}

cleanup()
{
    local cmd="sysbench $COMMON_CMD cleanup"
    log "eval \"$cmd\""
    eval "$cmd"
}

test_mode_list="simple complex"
read_only_list="on off"

myisam()
{
    local cmd="sysbench $TABLE_CMD --mysql-table-engine=myisam --myisam-max-rows=$myisam_max_rows prepare"
    eval "$cmd"
    for i in $(echo "$test_mode_list")
    do
        for j in $(echo "$read_only_list")
        do
           cmd="sysbench $TABLE_CMD --mysql-table-engine=myisam --myisam-max-rows=$myisam_max_rows \
                    --oltp-test-mode=$i --max-time=$duration --num-threads=$thread \
                    --max-requests=$max_req --oltp-read-only=$j run | tee $mysql_output_dir/myisam_${i}_${j}.txt"
           log "eval \"$cmd\""
           eval "$cmd"
        done
    done
    cleanup
}

stor_eng()
{
  local cmd=""
  prepare
  for k in $(echo "$storage_engine_list")
  do
      for i in $(echo "$test_mode_list")
      do
         for j in $(echo "$read_only_list")
         do
            cmd="sysbench $TABLE_CMD --mysql-table-engine=$k \
                  --oltp-test-mode=$i --max-time=$duration --num-threads=$thread \
                  --max-requests=$max_req --oltp-read-only=$j run | tee $mysql_output_dir/${k}_${i}_${j}.txt"
            log "eval \"$cmd\""
            eval "$cmd"
         done
      done
  done
  cleanup
}

mysql_test()
{
  mkdir $mysql_output_dir
  myisam
  stor_eng
}

log_level=2
mysql_test
