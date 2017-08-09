import os
import fio_summary
import gen_trend_all
import fio_summary

def old_fio():
  indir         = "/home/honzhan/NginxRoot/Experiment/*/fio_result/"
  in_csv_pat    = "*k_bs_bar"
  extr_date_pat = ".+/(\d+)/[a-zA-Z_0-9/]+\d+[kK]_bs_bar"
  out_csv_dir   = "fiocsv"
  out_chart_dir = "fiochart"
  sum_dir       = "sum"
  fio_html_tmpl = "tmpl/fiot_sum_tmpl"
  sum_html      = "summary.htm"
  fio_summary.filter_tbl_file(indir, in_csv_pat, extr_date_pat, True, out_csv_dir)
  fio_summary.filter_tbl_file(indir, in_csv_pat, extr_date_pat, False, out_chart_dir)
  gen_trend_all.gen_html_from_csv(out_chart_dir, out_csv_dir, sum_dir, False)
  gen_trend_all.gen_sum(sum_dir, fio_html_tmpl, sum_html)

def new_fio():
  indir         = "/home/honzhan/NginxRoot/Experiment/*/fio_result/"
  in_csv_pat    = "*_bs_tbl_normal_csv"
  extr_date_pat = ".+/(\d+)/[a-zA-Z_0-9/]+_bs_tbl_normal_csv"
  out_csv_dir   = "fiocsv"
  out_chart_dir = "fiochart"
  sum_dir       = "sum"
  fio_html_tmpl = "tmpl/fiot_sum_tmpl"
  sum_html      = "summary.htm"
  fio_summary.filter_csv_file(indir, in_csv_pat, extr_date_pat, True, out_csv_dir)
  fio_summary.filter_csv_file(indir, in_csv_pat, extr_date_pat, False, out_chart_dir)
  gen_trend_all.gen_html_from_csv(out_chart_dir, out_csv_dir, sum_dir, True)
  gen_trend_all.gen_sum(sum_dir, fio_html_tmpl, sum_html)
  
if __name__=="__main__":
  old_fio()
