#!/bin/sh
if [ $# -ne 2 ]
then
   echo "Specify output_file and duration(s)"
   exit 1
fi

top_cmd() {
  local i=1
  local output=$1
  local duration=$2
  local cont=1
  trap "cont=0" SIGINT SIGTERM
echo "" > $output
while [ $i -le $duration ] && [ $cont == "1" ]
do
   echo "===$i `date`===" >> $output
   top -b |head -n 30 >> $output
   sleep 1
   i=`expr $i + 1`
done
}

vmstat_cmd() {
   local output=$1
   local duration=$2
   vmstat -c $duration -P > $output
}

top_cmd $1 $2
#vmstat_cmd $1 $2
