#!/bin/sh
. perf_env.sh

g_final_output_body1=""
g_ifstat_desc=""

gen_view_html()
{
   local title="$1"
   local subtitle="$2"
   local indata_dir=$3
   local perf_tool=$4
   local test_start_time=`cat $status_dir/$start_time`
   local test_end_time=`cat $status_dir/$end_time`
   local perf04_tunable_option=$(get_tunable_option $perf04_corp_ip $perf04_corp_port)
   local perf03_tunable_option=$(get_tunable_option $perf03_corp_ip $perf03_corp_port)
   local perf04_sysctl_values=$(get_sysctl_option_list_values $perf04_corp_ip $perf04_corp_port $perf04_inter_ip)
   local perf03_sysctl_values=$(get_sysctl_option_list_values $perf03_corp_ip $perf03_corp_port $perf03_inter_ip)
   local top_file=""
   local out_dir=$(get_folder_from_path $indata_dir)
   local csv_chart_file=${perf_tool}${csv_chart_file_postfix}
   local csv_table_file=${perf_tool}${csv_table_file_postfix}

   for i in `ls -t $indata_dir/*${top_postfix}*`
   do
       top_file=${i##*/}
       
   done

   cat $html_header_tmpl > $final_output_file
cat << _EOF >> $final_output_file
    <script type="text/javascript">
      google.charts.load('current', {'packages':['line', 'table']});
      google.charts.setOnLoadCallback(drawChart);
      google.charts.setOnLoadCallback(drawTable);

    function drawChart() {
      var data = new google.visualization.DataTable();
      data.addColumn('number', 'Duration (sec)');
_EOF
## data for chart
   echo -e "$g_final_output_body1" >> $final_output_file
   echo "data.addRows([" >> $final_output_file
   cat $data_file >> $final_output_file
   echo "      ]);" >> $final_output_file
##
cat << EOF_ >> $final_output_file
      var options = {
        chart: {
          title: "$title",
          subtitle: "$subtitle"
        },
        width: 1500,
        height: 1000
      };

      var chart = new google.charts.Line(document.getElementById('linechart_material'));

      chart.draw(data, options);
    }

    function drawTable() {
	var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
	var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
	var data = new google.visualization.DataTable();
	data.addColumn('number', 'Connections');
        data.addColumn('number', 'Duration(s)');
        data.addColumn('number', 'Min(Gbps)');
        data.addColumn('number', 'Max(Gbps)');
	data.addColumn('number', 'Median(Gbps)');
	data.addColumn('number', 'Avg(Gbps)');
	data.addColumn('number', 'Stddev(Mbps)');
        data.addRows([
EOF_

# data for table
   cat $g_table_data_file >> $final_output_file
#
cat << E_O_F >> $final_output_file
        ]);

        var table = new google.visualization.Table(document.getElementById('table_div'));
        
        table.draw(data, options);
    }
  </script>
</head>
<body>
  <div class="container">
        <header>
            <h1>Network Performance Report</h1>
        </header>
        <div class="wrapper clearfix">
	  <div class="content">
                <section>
                    <h2>Environment</h2>
			<p>Time used for the whole run: from <b>"$test_start_time"</b> to <b>"$test_end_time"</b>.<p>
			<b>Environment for $perf04_corp_ip:$perf04_corp_port</b><br>
			<ul>
			    <li>CPU: $perf04_cpu_core</li>
			    <li>CPU details: "$perf04_cpu_info"</li>
			    <li>OS: "$perf04_uname"</li>
			    <li>tunable: "$perf04_tunable_option"</li>
			    <li>sysctl: "$perf04_sysctl_values"</li>
			    <li>static memory: "${perf04_mem}"</li>
			</ul>
		        <b>Environment for $perf03_corp_ip:$perf03_corp_port</b>
			<ul>
			    <li>CPU: $perf03_cpu_core</li>
			    <li>CPU details: "$perf03_cpu_info"</li>
			    <li>OS: "$perf03_uname"</li>
			    <li>tunable: "$perf03_tunable_option"</li>
			    <li>sysctl: "$perf03_sysctl_values"</li>
			    <li>static memory: "${perf03_mem}"</li>
			</ul>
		</section>
	  </div>
	  <div class="content">
                <section>
		    <h2>Result</h2>
		    <div><a href="$csv_table_file">Export table data to csv</a></div>
		    <div id="table_div"></div>
  		    <div><a href="$csv_chart_file">Export chart data to csv</a></div>
		    <div id="linechart_material"></div><br>
		</section>
	  </div>
E_O_F
   ## add statistics for top/vmstat if they are collected
   top_statistic=`ls -t $indata_dir/*${top_postfix}*`
   if [ "$top_statistic" != "" ]
   then
cat << EOF >> $final_output_file
          <div class="content">
                <section>
                    <h2>Statistics</h2>
EOF
	for i in `ls -t $indata_dir/*${top_postfix}*`
	do
		top_file=${i##*/}
cat << EOF >> $final_output_file
		    <div><a href="$out_dir/$top_file">$top_file</a></div>
EOF
	done
cat << EOF >> $final_output_file
		</section>
          </div>
EOF
   fi
cat << E_O_F >> $final_output_file
	</div>
	<footer>
		<p>copyright &copy; OSTC@microsoft.com</p>
	</footer>
  </div>
</body>
</html>
E_O_F
   log "Done in gen_view_html"
}

init_blank_result()
{
   if [ -e $data_file ]
   then
       rm $data_file
   fi
   local iter=1
   while [ $iter -le $duration ]
   do
       echo "[$iter" >> $data_file
       iter=`expr $iter + 1`
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
       iter=`expr $iter + 1`
   done
}

gen_final_body1()
{
   local conn=$1
   local newline="\n"
   g_final_output_body1=${g_final_output_body1}"      data.addColumn('number', '${conn} connections');"${newline}
}

collect_netperf_result()
{
   local dir=$1
   local prefix=$2
   local con
   local column
   local data_line
   #local total_line=$duration
   #local total_line_plus
   for i in `ls -t $dir/${prefix}*${ifstat_postfix}*`
   do
      con=`echo $i|awk -F _ '{a=NF-1}END{print $a}'`
      gen_final_body1 $con
      ## there are two columns data
      column=`awk '{if ($1 ~ /n\/a/); else s+=$1; if ($2 ~ /n\/a/); else t+=$2;}END{if (s < t) print 2; else print 1}' $i`
      if [ $column == "1" ]
      then
         g_ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $2 "(" $1 ")"}'`
      else
         g_ifstat_desc=`head -n 2 $i|tail -n 1|awk '{print $4 "(" $3 ")"}'`
      fi
      ## data to generate chart
      data_line=`expr 2 + $warm_dur`
      awk -v c=$column -v min=$ifstat_minval -v max=$ifstat_maxval -v len=$duration -v effect_data=$data_line 'BEGIN {
		i=1;j=1;
	}
	{
		if ($c >= min && $c < max && i <= len && j > effect_data) {
			printf("%d\n", $c);
			i++;
		}
		j++;
	}' $i > $tmp_dir/raw.data
      mv $data_file $tmp_dir/gen_result_tmp.data
      paste -d , $tmp_dir/gen_result_tmp.data $tmp_dir/raw.data > $data_file  
      ## data to generate table
      ministat -A $tmp_dir/raw.data | tail -n 1 | awk -v c=$con \
	'{printf("[%d, %d, %.2f, %.2f, %.2f, %.2f, %.2f],\n", c, $2, $3/1000000.0, $4/1000000.0, $5/1000000.0, $6/1000000.0, $7/1000.0)}' >> $g_table_data_file
   done
   mv $data_file $tmp_dir/gen_result_final.data
   paste -d " " $tmp_dir/gen_result_final.data $end_file > $data_file
}

cleanup()
{
   if [ -e $g_table_data_file ]
   then
      rm $g_table_data_file
   fi
   rm_tmp_dir_ifexist
}

init()
{
   init_blank_result
   init_end_column
   create_tmp_dir_ifnotexist
}

validate_input()
{
   local perf_tool=$1
   local m=1
   local m_len
   local marker
   local ret=1
   m_len=$(array_len "$marker_list" "$marker_list_sep")
   while [ $m -le $m_len ]
   do
      marker=$(array_get "$marker_list" $m "$marker_list_sep")
      if [ "$marker" == "$perf_tool" ]
      then
         ret=0
         break
      fi
      m=`expr $m + 1`
   done
   echo $ret
}

gen_html_process()
{
   if [ $# -ne 2 ]
   then
      echo "Specify dir <i|n|k>"
      exit 1
   fi

   local data_dir=$1
   local p_tool=$2

   init
   check_runtime_env
   local is_valid=$(validate_input "$p_tool")
   if [ $is_valid == 1 ]
   then
      echo "Invalid input '$p_tool'"
      log "Invalid input '$p_tool'"
      exit 1
   fi

   collect_netperf_result $data_dir $p_tool
   local html_desc=$(array_getvalue "$marker_to_htmldesc" "$p_tool" "$marker_list_sep" "$marker_to_htmldesc_sep")
   gen_view_html "$html_desc" "$g_ifstat_desc" $data_dir $p_tool

   cleanup
}

gen_html_process $*
