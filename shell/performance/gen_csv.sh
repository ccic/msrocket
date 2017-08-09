#!/bin/sh
. perf_env.sh


gen_netperf_csv()
{
   local prefix=$1
   local perf_tool=$2
   local tmp_dir=$3
   local con
   local column
   local data_line
   local first_row=""
   local tmp_tbl_file=$tmp_dir/tmp_tbl_file.data
   local csv_one_col_file=${perf_tool}_col_csv.data
   local csv_tmp_file=${perf_tool}_csv.data
   local csv_chart_file=${perf_tool}${csv_chart_file_postfix}
   local csv_table_file=${perf_tool}${csv_table_file_postfix}
   if [ -e $csv_tmp_file ]
   then
     rm $csv_tmp_file
   fi

   if [ -e $csv_chart_file ]
   then
     rm $csv_chart_file
   fi
   if [ -e $csv_table_file ]
   then
     rm $csv_table_file
   fi
   for i in `ls -t $dir/${prefix}*${ifstat_postfix}*`
   do
      con=`echo $i|awk -F _ '{a=NF-1}END{print $a}'`
      if [ "${first_row}" != "" ]
      then
         first_row=${first_row}", ${con} connections"
      else
         first_row="${con} connections"
      fi
      ## there are two columns data
      column=`awk '{if ($1 ~ /n\/a/); else s+=$1; if ($2 ~ /n\/a/); else t+=$2;}END{if (s < t) print 2; else print 1}' $i`
      if [ $column == "1" ]
      then
         ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $2 "(" $1 ")"}'`
      else
         ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $4 "(" $3 ")"}'`
      fi
      ## data to generate chart
      let data_line=2+$warm_dur > /dev/null
      awk -v c=$column -v min=$ifstat_minval -v max=$ifstat_maxval -v len=$duration -v effect_data=$data_line 'BEGIN {
		i=1;j=1;
	}
	{
		if ($c >= min && $c < max && i <= len && j > effect_data) {
			printf("%d\n", $c);
			i++;
		}
		j++;
	}' $i > $tmp_dir/$csv_one_col_file
      if [ -e $csv_tmp_file ]
      then
         mv $csv_tmp_file $tmp_dir/gen_csv_result.data
         paste -d , $tmp_dir/gen_csv_result.data $tmp_dir/$csv_one_col_file > $csv_tmp_file
      else
         cp $tmp_dir/$csv_one_col_file $csv_tmp_file
      fi
      
      ## data to generate table
      ministat -A $tmp_dir/$csv_one_col_file | tail -n 1| awk -v c=$con '{printf("%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f\n", c, $2, $3/1000000.0, $4/1000000.0, $5/1000000.0, $6/1000000.0, $7/1000.0)}' >> $tmp_tbl_file
   done
   echo $first_row > $csv_chart_file
   cat $csv_tmp_file >> $csv_chart_file
   echo "Connections,Duration(s),Min(Gbps),Max(Gbps),Median(Gbps),Avg(Gbps),Stddev(Mbps)" > $csv_table_file
   cat $tmp_tbl_file >> $csv_table_file

   rm $tmp_tbl_file  
}

gen_iperf_csv()
{
   local con
   local header
   local iperf_prefix=$1
   local perf_tool=$2
   local tmp_dir=$3
   local tmp_tbl_file=$tmp_dir/tmp_tbl_file.data
   local csv_one_col_file=${perf_tool}_col_csv.data
   local csv_tmp_file=${perf_tool}_csv.data
   local first_row=""
   local csv_chart_file=${perf_tool}${csv_chart_file_postfix}
   local csv_table_file=${perf_tool}${csv_table_file_postfix}
   if [ -e $csv_tmp_file ]
   then
     rm $csv_tmp_file
   fi
   if [ -e $csv_chart_file ]
   then
     rm $csv_chart_file
   fi
   if [ -e $csv_table_file ]
   then
     rm $csv_table_file
   fi
   for i in `ls -t $dir/${iperf_prefix}*${iperf_postfix}`
   do
      con=`echo $i|awk -F _ '{a=NF-1}END{print $a}'`
      if [ "${first_row}" != "" ]
      then
         first_row=${first_row}", ${con} connections"
      else
         first_row="${con} connections"
      fi
      ## data to generate chart
      if [ $con == 1 ]
      then
         let header=$duration+3 > /dev/null
         head -n $header $i|tail -n $duration| \
            awk '{if (match($8, "Mbits")) printf ("%.3f\n", $7/1000); else if (match($8, "Gbits")) print $7;}' > $tmp_dir/$csv_one_col_file
      else
         grep "SUM" $i|head -n $duration | \
            awk '{if (match($7, "Mbits")) printf ("%.3f\n", $6/1000); else if (match($7, "Gbits")) print $6;}' > $tmp_dir/$csv_one_col_file
      fi

      if [ -e $csv_tmp_file ]
      then
         mv $csv_tmp_file $tmp_dir/gen_csv_result.data
         paste -d , $tmp_dir/gen_csv_result.data $tmp_dir/$csv_one_col_file > $csv_tmp_file
      else
         cp $tmp_dir/$csv_one_col_file $csv_tmp_file
      fi

      ## data to generate table
      ministat -A $tmp_dir/$csv_one_col_file | tail -n 1 | awk -v c=$con '{printf("%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f\n", c, $2, $3/1024/1024, $4/1024/1024, $5/1024/1024, $6/1024/1024, $7/1024)}' >> $tmp_tbl_file
   done
   echo $first_row > $csv_chart_file
   cat $csv_tmp_file >> $csv_chart_file
   echo "Connections,Duration(s),Min(Gbps),Max(Gbps),Median(Gbps),Avg(Gbps),Stddev(Mbps)" > $csv_table_file
   cat $tmp_tbl_file >> $csv_table_file

   rm $tmp_tbl_file  
}


gen_csv_process()
{
if [ $# -ne 2 ]
then
   echo "Specify dir <i|n>"
   exit 1
fi

local dir=$1
local perf_tool=$2
local tmp_dir="gen_csv_tmp"
  if [ ! -d $tmp_dir ]
  then
    mkdir $tmp_dir
  fi
perf_prefix=$(array_getvalue "$marker_to_prefix" "$perf_tool" "$marker_list_sep" "$marker_to_prefix_sep")
gen_netperf_csv $perf_prefix $perf_tool $tmp_dir

  if [ -d $tmp_dir ]
  then
    rm -rf $tmp_dir
  fi
}

gen_csv_process $*
