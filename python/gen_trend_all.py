import os,re,shutil
import gen_trend_html

class TrendItem(object):
    def __init__(self, chart_file, csv_file):
        self.chart_file = chart_file
        self.csv_file   = csv_file
        chart_file_items = chart_file.split('/')
        self.name = chart_file_items[len(chart_file_items)-1]

def gen_sum(indir, sum_tmpl, sum_file):
    data = ""
    for f in os.listdir(indir):
      if f.endswith(".html"):
        file_path_item = f.split('/')
        file_name = file_path_item[len(file_path_item)-1]
        file_name_items = file_name.split('_')
        desc = "Block size: " + file_name_items[0] + " thread: " + file_name_items[1] + " mode: " + file_name_items[2]
        data = data + "                    <div><a href='" + file_name + "'>"
        data = data + desc + "</a></div>\n"
    with open(sum_tmpl, 'r') as tmpl_f:
        tmpl_content = tmpl_f.read()
    out_content = tmpl_content.replace('%BS_THREAD_MODE_IODEPTH_PLACEHOLDER%', data)
    with open(sum_file, 'w') as out_f:
        out_f.write(out_content)

def gen_html_from_csv(chart_dir, csv_dir, out_dir, is_new):
    if os.path.exists(out_dir):
        shutil.rmtree(out_dir)
    #os.makedirs(out_dir)
    shutil.copytree(csv_dir, os.path.join(out_dir))
    for f in os.listdir(chart_dir):
        print (f)
        file_path_item = f.split('/')
        chart_file_name = file_path_item[len(file_path_item)-1]
        csv_file_name = chart_file_name + ".csv"
        csv_file_path = os.path.join(csv_dir, csv_file_name)
        if os.path.exists(csv_file_path):
            out_html_file = chart_file_name + ".html"
            gen_trend_html.gen_html_from_chartdata_csvdata(os.path.join(chart_dir, f),
                csv_file_path, 'fiot_tmpl', os.path.join(out_dir, out_html_file), is_new)

if __name__=="__main__":
    gen_html_from_csv("fiochart", "fiocsv", "sum")
    gen_sum("sum", "fiot_sum_tmpl", "summary.htm")
