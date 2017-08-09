import os,re

def extract_date_info_from_chartline(chartline):
    split1 = chartline.split(')')
    split2 = split1[0].split('(')
    date_info = split2[1].split(',')
    return date_info[0] + date_info[1] + date_info[2] + date_info[3] + date_info[4] + date_info[5]

def gen_html_from_chartdata_csvdata(chart_file, csv_file, html_tmpl_file, out_html_file, is_new):
    with open(chart_file, 'r') as chart_f:
        chart_data = chart_f.read()
    with open(csv_file, 'r') as csv_f:
        csv_data = csv_f.read()
    with open(html_tmpl_file, 'r') as tmpl_f:
        tmpl_data = tmpl_f.read()
    ## replace
    chart_file_full_name = chart_file.split('/')
    chart_file_name = chart_file_full_name[len(chart_file_full_name)-1]
    chart_name_items = chart_file_name.split('_')
    result_description = "Block size: " + chart_name_items[0]
    result_description = result_description + ", thread: " + chart_name_items[1]
    result_description = result_description + ", mode: " + chart_name_items[2]
    if is_new:
      item_base = 3
    else:
      item_base = 2
    iolens = len(chart_name_items) - item_base
    col_data = "      data.addColumn('date', 'Date');\n"
    for i in range(0, iolens):
        iodepth = chart_name_items[i+item_base]
        col_data = col_data + "      data.addColumn('number', '" + iodepth + "');\n"
    out = tmpl_data.replace('%DATA_PLACEHOLDER%', chart_data)
    out = out.replace('%ADD_COLUMN_PLACEHOLDER%', col_data)
    out = out.replace('%REST_PLACEHOLDER%', result_description)
    csv_file_path_items = csv_file.split('/')
    csv_file_ilens = len(csv_file_path_items)
    out = out.replace('%CSV_FILE_LOCATION_PLACEHOLDER%', csv_file_path_items[csv_file_ilens-1])
    #out = out.replace('%CSV_FILE_LOCATION_PLACEHOLDER%', csv_file)

    history_date_link = ""
    chart_lines = chart_data.split('\n')
    for i in range(0, len(chart_lines) - 1):
        date_line = extract_date_info_from_chartline(chart_lines[i])
        history_date_link = history_date_link + "                    <div><a href='../" + date_line + "/fio.html'>"
        history_date_link = history_date_link + date_line + "</a></div>\n"
    out = out.replace('%HISTORY_DATA_PLACEHOLDER%', history_date_link)
    with open(out_html_file, 'w') as out_f:
        out_f.write(out)


if __name__=="__main__":
    gen_html_from_chartdata_csvdata('fiochart/4k_1_randread_1_16_32_64_128_256',
           'fiocsv/4k_1_randread_1_16_32_64_128_256.csv',
           'tmpl/fiot_tmpl', "4k_1_randread_1_16_32_64_128_256.html", True)
