#!/bin/sh
pid=`ps -C|grep "waagent"|awk '{print $1}'`
if [ "$pid" != "" ]
then
  kill $pid
fi
rm /var/log/waagent.log
