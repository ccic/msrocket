import os,re,shutil
import read_write

root_dir = "/home/honzhan/NginxRoot/Experiment"
def filter_csv_file(indir, csv_pat, outdir, is_outcsv):
  shell_cmd = "find " + indir + " -iname '" + csv_pat + "'"
  #print(shell_cmd)
  file_list = os.popen(shell_cmd)
  for item in file_list:
    i = item.strip("\n")
    print(i)
    pattern = r".+/(\d+)/\w+.csv"
    match = re.match(pattern, i)
    if match:
      read_write.read_content(i, pattern, outdir, is_outcsv)

def gen_network_trend(indir, csv_pat, outdir):
  if os.path.exists(outdir):
    shutil.rmtree(outdir)
  os.makedirs(outdir)
  filter_csv_file(indir, csv_pat, outdir, False) 
  filter_csv_file(indir, csv_pat, outdir, True) 

if __name__=="__main__":
  root_dir = "/home/honzhan/NginxRoot/Experiment"
  outdir = "network"
  csvpat = "k_table.csv"
  gen_network_trend(root_dir, csvpat, outdir)
