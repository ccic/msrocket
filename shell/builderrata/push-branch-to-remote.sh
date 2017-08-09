#!/bin/sh
basedir=`dirname $0`

. $basedir/config.sh

if [ $# -ne 1 ]
then
  echo "Specify the release version: <10_3|11_0>"
  exit 1
fi

push_branch_to_remote $*
