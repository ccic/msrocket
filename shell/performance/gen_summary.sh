#!/bin/sh
. perf_env.sh

gen_table_chart_from_csv()
{
	local file_path=$1
	local output_file=$2
	local line_no=`wc -l $file_path|awk '{print $1}'`
	local i=1
	local first_col_file=$tmp_dir/first_col_file.txt
	local end_col_file=$tmp_dir/end_col_file.txt
	local table_content=$tmp_dir/table_content.txt
	local tmp_file=$tmp_dir/tmp_file.txt

	if [ -e $first_col_file ]
	then
		rm $first_col_file
	fi
	if [ -e $end_col_file ]
	then
		rm $end_col_file
	fi

	while [ $i -lt $line_no ]
	do
		echo "[" >> $first_col_file
		echo "]," >> $end_col_file
		let "i=$i+1" >/dev/null
	done
	awk '{if (FNR > 1) {print $0}}' $file_path > $table_content
	paste $first_col_file $table_content >$tmp_file
	paste $tmp_file $end_col_file > $output_file
}

gen_description_section() {
	local g_config="$1"
	local r_config="$2"
	local general_desc=$(explain_green_config_general "$g_config")
	local improve_desc=$(explain_green_config_detail "$g_config")
	local drop_desc=$(explain_red_config_detail "$r_config")
cat << EOF >> $summary_html_file
		      <div class="content">
			<section>
			   <h1>Some explanations about performance report</h1>
			   <ul>
EOF
	echo "$general_desc" >> $summary_html_file
	echo "$improve_desc" >> $summary_html_file
	echo "$drop_desc"  >> $summary_html_file
cat << EOF >> $summary_html_file
			   </ul>
			</section>
		      </div>
EOF
}

gen_js_percent_table() {
	local dst_csv_path=$1
	local src_csv_path=$2
	local prefix=$3
	local reg_imp_status_file=$tmp_dir/${prefix}_reg_imp_status.txt
	## create netperf table
	if [ -e $dst_csv_path ] && [ -e $src_csv_path ]
	then
		
cat << EOF >> $summary_html_file
      google.charts.setOnLoadCallback(drawPercentTable_${prefix});
      function drawPercentTable_${prefix}() {
	var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
	var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
	var data = new google.visualization.DataTable();
	data.addColumn('number', 'Connections');
        data.addColumn('number', 'Duration(s)');
        data.addColumn('number', 'Min(%)');
        data.addColumn('number', 'Max(%)');
	data.addColumn('number', 'Median(%)');
	data.addColumn('number', 'Avg(%)');
	data.addColumn('number', 'Stddev(%)');
        data.addRows([
EOF
		echo "gen_percent_tbl $src_csv_path $dst_csv_path >> $summary_html_file"
		gen_percent_tbl $src_csv_path $dst_csv_path >> $summary_html_file
cat << EOF >> $summary_html_file
        ]);

        var table = new google.visualization.Table(document.getElementById('${prefix}_percent_table_div'));
EOF
	# regression or improvement check
		compare2nic $src_csv_path $dst_csv_path > $reg_imp_status_file
		while read line
		do
			row=`echo "$line"|awk -F , '{print $1}'`
			let row=$row-1 > /dev/null
			col=`echo "$line"|awk -F , '{print $2}'`
			let col=$col-1> /dev/null
			color=`echo "$line"|awk -F , '{print $3}'`
cat << EOF >> $summary_html_file
	data.setCell($row, $col, undefined, undefined, {style: "background-color:$color"});
EOF
		done < $reg_imp_status_file
cat << EOF >> $summary_html_file 
        table.draw(data, options);
      }
EOF
	fi
}

gen_js_table() {
	local dst_csv_path=$1
	local src_csv_path=$2
	local prefix=$3
	local dst_table_file=$tmp_dir/${prefix}_table_gen.txt
	local reg_imp_status_file=$tmp_dir/${prefix}_reg_imp_status.txt
	## create netperf table
	if [ -e $dst_csv_path ]
	then
		log "gen_table_chart_from_csv $dst_csv_path $dst_table_file"
		gen_table_chart_from_csv $dst_csv_path $dst_table_file
cat << EOF >> $summary_html_file
      google.charts.setOnLoadCallback(drawTable_${prefix});
      function drawTable_${prefix}() {
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
EOF
	## netperf table data
	cat $dst_table_file >> $summary_html_file
cat << EOF >> $summary_html_file
        ]);

        var table = new google.visualization.Table(document.getElementById('${prefix}_table_div'));
EOF
	# regression or improvement check
		if [ -e $src_csv_path ]
		then
			compare2nic $src_csv_path $dst_csv_path > $reg_imp_status_file
			while read line
			do
				row=`echo "$line"|awk -F , '{print $1}'`
				let row=$row-1 > /dev/null
				col=`echo "$line"|awk -F , '{print $2}'`
				let col=$col-1> /dev/null
				color=`echo "$line"|awk -F , '{print $3}'`
cat << EOF >> $summary_html_file
	data.setCell($row, $col, undefined, undefined, {style: "background-color:$color"});
EOF
			done < $reg_imp_status_file
		fi
cat << EOF >> $summary_html_file 
        table.draw(data, options);
      }
EOF
	fi
}

gen_html_body() {
	local dst_csv_path=$1
	local src_csv_path=$2
	local prefix=$3
	local server_ip=`ifconfig hn0 | grep "inet "|awk '{print $2}'`
	local is_valid_src=`echo $src_dir|awk '{if ($1 ~ /^[+-]?[0-9]+$/) {print 1;} else {print 0;}}'`
		if [ -e $dst_csv_path ]
		then
cat << EOF >> $summary_html_file
		      <div class="content">
			<section>
			   <h1>$prefix Performance Data</h1>
			   <table>
			     <tr>
				<td><a href="${web_protocol}://${server_ip}:${webserver_port}/$dst_dir/${prefix}.html">latest data: $dst_dir</a></td>
EOF
				if [ $is_valid_src == 1 ]
				then
cat << EOF >> $summary_html_file
				<td><a href="${web_protocol}://${server_ip}:${webserver_port}/$src_dir/${prefix}.html">old data: $src_dir</a></td>
EOF
				fi
cat << EOF >> $summary_html_file
			     </tr>
			   </table>
EOF
			if [ -e $src_csv_path ]
			then
cat << EOF >> $summary_html_file
			   <table>
			     <tr>
				<td><div id="${prefix}_table_div"></div></td>
				<td><div id="${prefix}_percent_table_div"></div></td>
			     </tr>
			   </table>
EOF
			else
cat << EOF >> $summary_html_file
			   <div id="${prefix}_table_div"></div>
EOF
			fi
cat << EOF >> $summary_html_file
			</secion>
		      </div>
EOF
		fi
}

gen_storage_js_table() {
	local dst_file=$1
	local src_file=$2
	local storage_prefix=$3
	local storage_result_folder=$4
	local dst_mode_list=""
	local thd_list=""
	local tmp_dst_content_file=$tmp_dir/dst_content.txt
	local tmp_src_content_file=$tmp_dir/src_content.txt
	local tmp_cmp_rg_file=$tmp_dir/${storage_prefix}_rg_tmp.txt
	local bs=""
	local prefix=""
	local i
	local j
	if [ -e $dst_file ]
	then
   	   awk '{
		if (FNR > 1) {
		    print($0);
		}
	   }' $dst_file |sort -t , -k 2 >$tmp_dst_content_file
	   bs=`head -n 1 $tmp_dst_content_file|awk -F , '{print $1}'`
	   for i in `awk -F , '{print($2)}' $tmp_dst_content_file|sort|uniq`
	   do
		dst_mode_list=$dst_mode_list" "$i
	   done
	   for i in `awk -F , '{print($4)}' $tmp_dst_content_file|sort|uniq`
	   do
	      prefix=${storage_prefix}_${bs}_${i}
cat << EOF >> $summary_html_file
      google.charts.setOnLoadCallback(drawTable_${prefix});
      function drawTable_${prefix}() {
	var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
	var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
	var data = new google.visualization.DataTable();
	data.addColumn('string', 'IODepth');
EOF
	      for j in $dst_mode_list
	      do
cat << EOF >> $summary_html_file
	data.addColumn('number', '$j');
EOF
	      done
cat << EOF >> $summary_html_file
	data.addRows([
EOF
	      cat ${result_path}/$dst_dir/$storage_result_folder/${bs}_${i}_${bs_postfix_table} >> $summary_html_file
cat << EOF >> $summary_html_file
	]);
        var table = new google.visualization.Table(document.getElementById('${prefix}_table_div'));
	table.draw(data, options);
      }
EOF
	      if [ -e $src_file ]
	      then
cat << EOF >> $summary_html_file
      google.charts.setOnLoadCallback(drawTable_${prefix}_percent);
      function drawTable_${prefix}_percent() {
        var cssClassNames = {
              headerCell: 'headerCell',
              tableCell: 'tableCell'};
        var options = {showRowNumber: true,'allowHtml': true, 'cssClassNames': cssClassNames, 'alternatingRowStyle': true};
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'IODepth');
EOF
		for j in $dst_mode_list
		do
cat << EOF >> $summary_html_file
        data.addColumn('number', '$j');
EOF
		done
cat << EOF >> $summary_html_file
        data.addRows([
EOF
		gen_percentage_for_storage $i $src_file $dst_file >> $summary_html_file
cat << EOF >> $summary_html_file
        ]);
        var table = new google.visualization.Table(document.getElementById('${prefix}_percent_table_div'));
EOF
		compare2storage $i $src_file $dst_file $storage_prefix > $tmp_cmp_rg_file
		while read line
		do
			row=`echo "$line"|awk -F , '{print $1}'`
			row=`expr $row - 1`
			col=`echo "$line"|awk -F , '{print $2}'` ## The column index does not need to minus 1, since "Thread" is the 1st column
			color=`echo "$line"|awk -F , '{print $3}'`
cat << EOF >> $summary_html_file
	data.setCell($row, $col, undefined, undefined, {style: "background-color:$color"});
EOF
		done < $tmp_cmp_rg_file
cat << EOF >> $summary_html_file
        table.draw(data, options);
      }
EOF
	      fi
	   done
	fi
}

gen_storage_cmp_body() {
	local prefix=$1
	local show_dst=$2
	local show_src=$3
	local server_ip=`ifconfig hn0 | grep "inet "|awk '{print $2}'`
	if [ $show_dst == 1 ]
	then
cat << EOF >> $summary_html_file
		      <div class="content">
			<section>
			   <h1>$prefix Performance Data</h1>
			   <table>
			     <tr>
				<td><a href="${web_protocol}://${server_ip}:${webserver_port}/$dst_dir/${prefix}.html">latest data: $dst_dir</a></td>
EOF
				if [ $show_src == 1 ]
				then
cat << EOF >> $summary_html_file
				<td><a href="${web_protocol}://${server_ip}:${webserver_port}/$src_dir/${prefix}.html">old data: $src_dir</a></td>
EOF
				fi
cat << EOF >> $summary_html_file
			     </tr>
			   </table>
			   <ul>
EOF
	fi	
}

gen_storage_bs_div_body() {
	local dst_file=$1
	local src_file=$2
	local storage_prefix=$3
	local csv_file=$dst_file
	local marker=""
	local prefix=""
	local thd_list=""
	local tmp_dst_content_file=$tmp_dir/dst_content.txt
	if [ -e $dst_file ]
	then
		csv_file=${dst_file##*/}
		marker=`echo $csv_file|awk -F _ '{print $1}'`
		awk -F , '{
		if (FNR > 1) {
		    print($4);
		}
		}' $dst_file |sort|uniq >$tmp_dst_content_file
		for i in `cat $tmp_dst_content_file`
		do
			thd_list=$thd_list" "$i

		prefix=${storage_prefix}_${marker}_${i}
			if [ -e $src_file ]
			then
cat << EOF >> $summary_html_file
			   <li>Block size: $marker, thread: ${i}
			   <table>
			     <tr>
				<td><div id="${prefix}_table_div"></div></td>
				<td><div id="${prefix}_percent_table_div"></div></td>
			     </tr>
			   </table>
			   </li>
EOF
			else
cat << EOF >> $summary_html_file
			   <li>Block size: $marker<div id="${prefix}_table_div"></div></li>
EOF
			fi
		done
	fi
}

gen_storage_bs_div_end() {
cat << EOF >> $summary_html_file
			   </ul>
			</secion>
		      </div>
EOF
}

is_storage_dst_exist() {
	local result_folder=$1
	local csv_table_postfix=$2

	local dst_csv_folder=${result_path}/$dst_dir/$result_folder
	local csv_file=""
	if [ ! -e $dst_csv_folder ]
	then
		echo 0
		return
	fi
	for i in `ls $dst_csv_folder/*${csv_table_postfix}`
	do
	    csv_file=${i##*/}
	    if [ -e $dst_csv_folder/$csv_file ]
	    then
		echo 1
		return
	    fi
	done
	echo 0
}

is_storage_src_exist() {
	local result_folder=$1
	local csv_table_postfix=$2
	
	local dst_csv_folder=${result_path}/$dst_dir/$result_folder
	local src_csv_folder=${result_path}/$src_dir/$result_folder
	local csv_file=""

	if [ ! -e $src_csv_folder ] || [ ! -e $dst_csv_folder ]
        then
                echo 0
                return
        fi
	for i in `ls $dst_csv_folder/*${csv_table_postfix}`
	do
	    csv_file=${i##*/}
	    if [ -e $dst_csv_folder/$csv_file ] && [ -e $src_csv_folder/$csv_file ]
	    then
		echo 1
		return
	    fi
	done
	echo 0
}

gen_storage_cmp_js() {
	local result_folder=$1
	local csv_table_postfix=$2
	local storage_prefix=$3
	local dst_csv_folder=${result_path}/$dst_dir/$result_folder
	local src_csv_folder=${result_path}/$src_dir/$result_folder
	local csv_file=""
	for i in `ls $dst_csv_folder/*${csv_table_postfix}`
	do
	   csv_file=${i##*/}
	   gen_storage_js_table $dst_csv_folder/$csv_file $src_csv_folder/$csv_file $storage_prefix $result_folder
	done
}

gen_storage_body_div() {
	local result_folder=$1
	local csv_table_postfix=$2
	local storage_prefix=$3
	local dst_csv_folder=${result_path}/$dst_dir/$result_folder
	local src_csv_folder=${result_path}/$src_dir/$result_folder
	local csv_file=""
	for i in `ls $dst_csv_folder/*${csv_table_postfix}`
	do
	   csv_file=${i##*/}
	   gen_storage_bs_div_body $dst_csv_folder/$csv_file $src_csv_folder/$csv_file $storage_prefix
	done
}

gen_cmp_html() {
	local is_valid_dst=`echo $dst_dir|awk '{if ($1 ~ /^[+-]?[0-9]+$/) {print 1;} else {print 0;}}'`
	local is_valid_src=`echo $src_dir|awk '{if ($1 ~ /^[+-]?[0-9]+$/) {print 1;} else {print 0;}}'`
	if [ $is_valid_dst != 1 ]
	then
		log "dst dir '$dst_dir' is invalid, and stop the process"
		return
	fi
	if [ $is_valid_src != 1 ]
	then
		log "src dir '$src_dir' is invalid but can continue"
	fi
	cat $html_header_tmpl > $summary_html_file
###
cat << EOF >> $summary_html_file
    <script type="text/javascript">
      google.charts.load('current', {'packages':['line', 'table']});
EOF
##
	local m=1
	local marker
	local marker2prefix
	local marker_csv_table_file
	local dst_marker_csv_path
	local src_marker_csv_path
	local m_len=$(array_len "$marker_list" "$marker_list_sep")
	while [ $m -le $m_len ]
	do
	    marker=$(array_get "$marker_list" $m "$marker_list_sep")
	    marker2prefix=$(array_getvalue "$marker_to_prefix" "$marker" "$marker_list_sep" "$marker_to_prefix_sep")
	    marker_csv_table_file=${marker}${csv_table_file_postfix}
	    dst_marker_csv_path=${result_path}/$dst_dir/$marker_csv_table_file
	    src_marker_csv_path=${result_path}/$src_dir/$marker_csv_table_file
	    ## create the chart table
	    gen_js_table $dst_marker_csv_path $src_marker_csv_path $marker2prefix
	    gen_js_percent_table $dst_marker_csv_path $src_marker_csv_path $marker2prefix
	    m=`expr $m + 1`
	done

	local stor_len=$(array_len "$storage_prefix_list" "$storage_prefix_sep")
	local stor=1
	local stor_item
	local storage_result_folder
	local storage_csv_table
	local is_storage_dst_exist
	while [ $stor -le $stor_len ]
	do
	    stor_item=$(array_get "$storage_prefix_list" $stor "$storage_prefix_sep")
	    storage_result_folder=${stor_item}${storage_result_folder_postfix}
	    storage_csv_table=${stor_item}${csv_table_file_postfix}
	    is_storage_dst_exist=$(is_storage_dst_exist $storage_result_folder $storage_csv_table $stor_item)
	    if [ $is_storage_dst_exist == 1 ]
	    then
		gen_storage_cmp_js $storage_result_folder $storage_csv_table $stor_item
	    fi
	    stor=`expr $stor + 1`
	done
cat << EOF >> $summary_html_file
  </script>
</head>
<body>
  <div class="container">
        <header>
            <h1>FreeBSD Performance Report Summary $dst_dir</h1>
        </header>
	<div style="margin: 0 auto;">
            <ul class="tabs" data-persist="true">
                <li><a href="#network">Network</a></li>
                <li><a href="#storage">Storage</a></li>
            </ul>
	    <div class="tabcontents">
                <div id="network">
        	   <div class="wrapper clearfix">
EOF
	## create description
	gen_description_section "$green_config" "$red_config"
	
	m=1
	while [ $m -le $m_len ]
	do
	    marker=$(array_get "$marker_list" $m "$marker_list_sep")
	    marker2prefix=$(array_getvalue "$marker_to_prefix" "$marker" "$marker_list_sep" "$marker_to_prefix_sep")
	    marker_csv_table_file=${marker}${csv_table_file_postfix}
	    dst_marker_csv_path=${result_path}/$dst_dir/$marker_csv_table_file
	    src_marker_csv_path=${result_path}/$src_dir/$marker_csv_table_file
	    ## create html body
	    gen_html_body $dst_marker_csv_path $src_marker_csv_path $marker2prefix
	    m=`expr $m + 1`
	done

cat << EOF >> $summary_html_file
	           </div>
	        </div>
		<div id="storage">
		   <div class="wrapper clearfix">
EOF
	## join all the red/green description for storage
	stor=1
	local stor_r_desc=""
	local stor_g_desc=""
	while [ $stor -le $stor_len ]
	do
	    stor_item=$(array_get "$storage_prefix_list" $stor "$storage_prefix_sep")
	    r_desc_item=$(derefer_2vars $stor_item "_red_config")
            g_desc_item=$(derefer_2vars $stor_item "_green_config")
	    if [ "$r_desc_item" != "" ] && [ "$g_desc_item" != "" ]
	    then
		if [ "$stor_r_desc" == "" ]
		then
		    stor_r_desc="$r_desc_item"
		else
		    stor_r_desc="${stor_r_desc}:${r_desc_item}"
		fi
		if [ "$stor_g_desc" == "" ]
		then
		    stor_g_desc="$g_desc_item"
		else
		    stor_g_desc="${stor_g_desc}:${g_desc_item}"
		fi
	    fi
	    stor=`expr $stor + 1`
	done
	gen_description_section "$stor_g_desc" "$stor_r_desc"

	stor=1
	while [ $stor -le $stor_len ]
	do
	    stor_item=$(array_get "$storage_prefix_list" $stor "$storage_prefix_sep")
	    storage_result_folder=${stor_item}${storage_result_folder_postfix}
	    storage_csv_table=${stor_item}${csv_table_file_postfix}
	    is_storage_dst_exist=$(is_storage_dst_exist $storage_result_folder $storage_csv_table $stor_item)
	    is_storage_src_exist=$(is_storage_src_exist $storage_result_folder $storage_csv_table $stor_item)
	    gen_storage_cmp_body $stor_item $is_storage_dst_exist $is_storage_src_exist
	    if [ $is_storage_dst_exist == 1 ]
	    then
		gen_storage_body_div $storage_result_folder $storage_csv_table $stor_item
		gen_storage_bs_div_end
	    fi
	    stor=`expr $stor + 1`
	done
cat << EOF >> $summary_html_file
		   </div>
		</div>
	    </div>
	</div>
	<footer>
		<p>copyright &copy; OSTC@microsoft.com</p>
	</footer>
  </div>
</body>
</html>
EOF
}

normal_path() {
	local path=$1
	local len=`echo ""|awk -v a=$path '{printf("%d\n", length(a))}'`
	local slash=`echo $path|cut -c $len`
	if [ $slash == "/" ]
	then
		let len=$len-1 > /dev/null
		path=`echo $path|cut -c -$len`
	fi
	echo ${path##*/}
}

if [ $# -eq 2 ]
then
	dst_dir_path=$2
	src_dir_path=$1
	dst_dir=$(normal_path $dst_dir_path)
	src_dir=$(normal_path $src_dir_path)
else
	if [ $# -eq 0 ]
	then
		dst_dir=`ls -t $result_path|head -n 1`
		src_dir=`ls -t $result_path|head -n 2|tail -n 1`
	else
		echo "Specify dest_dir src_dir or not specify any folder"
		exit 1
	fi
fi
log_level=2
create_tmp_dir_ifnotexist
gen_cmp_html
