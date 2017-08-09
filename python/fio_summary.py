import os,re,shutil
import fio_csv_parser

def filter_tbl_file(indir, csv_pat, pattern, gen_csv, outdir):
  writedir=outdir
  if os.path.exists(writedir):
    shutil.rmtree(writedir)
  os.makedirs(writedir)
  shell_cmd = "find " + indir + " -iname '" + csv_pat + "'"
  #print (shell_cmd)
  file_list = os.popen(shell_cmd)
  for item in file_list:
    i = item.strip("\n")
    print(i)
    match = re.match(pattern, i)
    if match:
      print(match.group(1))
      fio_csv_parser.store_read_old_content(i, pattern, writedir, gen_csv)

def filter_csv_file(indir, csv_pat, pattern, gen_csv, outdir):
  writedir=outdir
  if os.path.exists(writedir):
    shutil.rmtree(writedir)
  os.makedirs(writedir)
  shell_cmd = "find " + indir + " -iname '" + csv_pat + "'"
  file_list = os.popen(shell_cmd)
  for item in file_list:
    i = item.strip("\n")
    match = re.match(pattern, i)
    if match:
      print(match.group(1))
      fio_csv_parser.store_read_content(i, pattern, writedir, gen_csv)

def gen_diff_iodepth():
  indir="/home/honzhan/NginxRoot/Perf/*/fio_result/"
  in_csv_pat="*_bs_tbl_normal_csv"
  extr_date_pat=".+/(\d+)/[a-zA-Z_0-9/]+_bs_tbl_normal_csv"
  out_csv_dir="fiocsv"
  out_chart_dir="fiochart"
  filter_csv_file(indir, in_csv_pat, extr_date_pat, True, out_csv_dir)
  filter_csv_file(indir, in_csv_pat, extr_date_pat, False, out_chart_dir)

def gen_old_fio():
  indir="/home/honzhan/NginxRoot/Perf/*/fio_result/"
  in_csv_pat="*k_bs_bar"
  extr_date_pat=".+/(\d+)/[a-zA-Z_0-9/]+\d+[kK]_bs_bar"
  out_csv_dir="fiocsv"
  out_chart_dir="fiochart"
  filter_tbl_file(indir, in_csv_pat, extr_date_pat, True, out_csv_dir)

if __name__=="__main__":
  #gen_diff_iodepth
  gen_old_fio()
