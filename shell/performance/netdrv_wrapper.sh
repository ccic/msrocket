#!/bin/sh

# This script depends on three other scrips
# @param1: ethernet interface, e.g. hn0 or ethn0
# @param2: log_tag for logger, e.g. "NETPERF"
# @param3: duration (s), e.g. 300
# @param4: ifstat output file
# @param5: statistic output file

log() {
  local log_tag=$1
  local msg="$2"
  logger -t $log_tag "$msg"
}

if [ $# -ne 7 ]
then
   logger -t "NETDRV" "Please specify correct 7 arguments: <ethernet> <log_tag> <duration> <ifstat_out> <top_out> <stat_script> <drv_script>"
   exit 1
fi
ethernet=$1
log_tag=$2
duration=$3
ifstat_out=$4
top_out=$5
collect_stat_script=$6
drv_script=$7

if [ ! -e $collect_stat_script ]
then
   log $log_tag "Cannot find $collect_stat_script"
   exit 1
fi

if [ ! -e $drv_script ]
then
   log $log_tag "Cannot find $drv_script"
   exit 1
fi

if [ -e $ifstat_out ]
then
   rm $ifstat_out
fi

nohup ifstat -b -i $ethernet -n > $ifstat_out &
pid=$!
log $log_tag "launch ifstat $pid"
log $log_tag "Start collect top"
nohup sh $collect_stat_script $top_out $duration &
stat_pid=$!
sh $drv_script

counter=1
expect_line=`expr $duration + 2`
line=`wc -l $ifstat_out|awk '{print $1}'`
while [ $line -lt $expect_line ]
do
   sleep 1
   if [ $counter -ge $duration ]
   then
      log $log_tag "Exceed timeout in $0"
      break
   fi
   counter=`expr $counter + 1`
   line=`wc -l $ifstat_out|awk '{print $1}'`
done
kill -9 $pid
log $log_tag "kill ifstat $pid"
kill -s TERM $stat_pid
log $log_tag "Terminate $stat_pid"
