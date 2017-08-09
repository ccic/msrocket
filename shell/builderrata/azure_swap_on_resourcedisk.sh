#!/bin/bash
###############################################################
# This script targets to create swap partition on resource disk
###############################################################

#sysctl dev.storvsc | grep "deviceid"
#dev.storvsc.1.%pnpinfo: classid=32412632-86cb-44a2-9b5c-50d1417354f5 deviceid=00000000-0001-8899-0000-000000000000
   devid=`sysctl dev.storvsc | grep "deviceid=00000000-0001" | awk '{print $1}'|awk -F . '{print $3}'`
   blkdev="blkvsc"$devid
   stordev="storvsc"$devid
   ret=`camcontrol devlist -b| grep "$blkdev"`
   if [ "$ret" == "" ]
   then
      ret=`camcontrol devlist -b| grep "$stordev"`
   fi
   # 'scbus3 on blkvsc1 bus 0'
   ret=`echo "$ret"|awk '{print $1}'`
   # find da1 from '<Msft Virtual Disk 1.0> at scbus3 target 1 lun 0 (da1,pass2)'
   ret=`camcontrol devlist | grep "$ret" | awk -F \( '{print $2}'|awk -F , '{print $1}'`
   #echo $ret
   devid=$ret
   parttype=`gpart show $devid| head -n 1 | awk '{print $5}'`
   if [ "$parttype" == "MBR" ]
   then
      partition="/dev/"$devid"s1"
   else
      partition="/dev/"$devid"p2"
   fi
   ret=`mount|grep "$partition"`
   swappart="/dev/"$devid
   if [ "$ret" == "" ]
   then
      swapon $swappart
      if [ $? -eq 0 ]
      then
         echo "Successfully use $swappart as swap partition"
      else
         echo "Fail to 'swapon $swappart'"
      fi
   else
      echo "!!Warning: the device $partition has been mounted as resource disk, please unmount it first!"
   fi
