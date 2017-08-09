#!/bin/sh

mysql_user=root
mysql_pass=User@123
mysql_db=test
table_size=20000000
myisam_max_rows=60000000
thread=8
duration=60

LOG_PREFIX=SYSBENCH
COMMON_CMD="--test=oltp --mysql-user=${mysql_user} --mysql-password=${mysql_pass} --mysql-db=$mysql_db"
TABLE_CMD="$COMMON_CMD --oltp-table-size=$table_size"
mysql_output_dir=mysql_`date +%Y%m%d%H%M%S`
