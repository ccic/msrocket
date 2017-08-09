#!/bin/sh
. perf_env.sh

if [ $# -ne 2 ]
then
   echo "Specify dir file_prefix"
   exit 1
fi

dir=$1
prefix=$2
iter=1
final_output_body1=""

gen_view_html()
{
   if [ -e $final_output_file ]
   then
      rm $final_output_file
   fi
   cat $tmpl_header_file > $final_output_file
   echo "$final_output_body1" >> $final_output_file
   echo "data.addRows([" >> $final_output_file
   cat $data_file >> $final_output_file
   cat $tmpl_footer_file >> $final_output_file
}

init_blank_result()
{
   if [ -e $data_file ]
   then
       rm $data_file
   fi
   iter=1
   while [ $iter -le $duration ]
   do
       echo "[$iter" >> $data_file
       let "iter=$iter+1" >/dev/null
   done
}

init_end_column()
{
   if [ -e $end_file ]
   then
       rm $end_file
   fi
   iter=1
   while [ $iter -le $duration ]
   do
       echo "]," >> $end_file
       let "iter=$iter+1" >/dev/null
   done
}

gen_final_body1()
{
   for i in $(echo $connection_iter)
   do
       final_output_body1=${final_output_body1}"data.addColumn('number', '${i} connections');"
   done
}

gen_result()
{
   for i in `ls -t $dir/${prefix}*`
   do
      grep "SUM" $i|head -n $duration | awk '{print $6}' > /tmp/raw.data
      mv $data_file /tmp/gen_result_tmp.data
      paste -d , /tmp/gen_result_tmp.data /tmp/raw.data > $data_file  
   done
   mv $data_file /tmp/gen_result_final.data
   paste -d " " /tmp/gen_result_final.data $end_file > $data_file
}

init_blank_result
init_end_column
gen_final_body1
gen_result
gen_view_html
