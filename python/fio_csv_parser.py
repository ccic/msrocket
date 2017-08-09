import os,re,shutil,datetime
import util

def store_read_old_content(readfilepath, pattern, writedir, outputcsv):
  ## parse the file name to get block_size and thread
  dir_items = readfilepath.split('/')
  item_no = len(dir_items)
  #print (dir_items[item_no-1])
  filename_items = dir_items[item_no-1].split('_')
  out_f = filename_items[0]  ## bs_thread
  
  date_mark = None
  match = re.match(pattern, readfilepath)
  if match:
    date_mark = match.group(1)                         ## extract date
  if not outputcsv:
    chart_date = "new Date(" + util.get_date_details(date_mark) + ")"
  else:
    chart_date = util.get_date_iso8601(date_mark)
  threads = []
  i = 1
  with open(readfilepath, "r") as f:
    line = f.readline().strip("\n")
    while line:
      content = line.split(",")
      if i == 1:
        title = content
      else:
        thd = content[0]
        if thd.startswith("['"):
           thd = thd[2:]
        if thd.endswith("'"):
           thd = thd.strip("'")
        threads.append(thd)
      line = f.readline().strip("\n")
      i = i + 1
  ## get mode list
  modlist = ""
  for ind in range(len(title)-1):
    if ind == 0:
      continue
    mod = title[ind]
    if mod.startswith("'"):
       mod = mod[1:]
    if mod.endswith("'"):
       mod = mod.strip("'")
    if mod.endswith("']"):
       mod = mod.strip("']")
    if len(modlist) == 0:
       modlist = mod
    else:
       modlist = modlist + "_" + mod
  ## prepare the record
  for idx in range(len(threads)-1):
    out_f = out_f + "_" + threads[idx] + "_" + modlist ## bs_thread_modlist
    record = ""
    i = 0
    with open(readfilepath, "r") as f:
      line = f.readline().strip("\n")
      while line:
        content = line.split(",")
        line = f.readline().strip("\n")
        i = i + 1
        if i == 1:
          continue
        else:
          thd = content[0]
          if thd.startswith("['"):
            thd = thd[2:]
          if thd.endswith("'"):
            thd = thd.strip("'")
          if thd == threads[idx]:
            for j in range(len(content)-1):
              if j == 0:
                 continue
              item = content[j]
              if item.endswith("]"):
                 item = item.strip("]")
              if len(record) == 0:
                 record = item
              else:
                 record = record + "," + item
    ##    
    write_file_path = os.path.join(writedir, out_f)
    if outputcsv:
       write_file_path = write_file_path + ".csv"
       if not os.path.exists(write_file_path):
       ## write title
         with open(write_file_path, "a") as fw:
           write_content = "Date," + modlist.replace('_', ',') + "\n"
           fw.write(write_content)
    with open(write_file_path, "a") as fw:
       if outputcsv:
         write_content = chart_date + "," + record + "\n"
       else:
         write_content = "[" + chart_date + "," + record + "],\n"
       fw.write(write_content)

def store_read_content(readfilepath, pattern, writedir, outputcsv):
  if not os.path.exists(writedir):
    os.makedirs(writedir)
  ## parse the file name to get block_size and thread
  dir_items = readfilepath.split('/')
  item_no = len(dir_items)
  #print (dir_items[item_no-1])
  filename_items = dir_items[item_no-1].split('_')
  out_f = filename_items[0] + "_" + filename_items[1]  ## bs_thread

  date_mark = None
  match = re.match(pattern, readfilepath)
  if match:
    date_mark = match.group(1)                         ## extract date
  if not outputcsv:
    chart_date = "new Date(" + util.get_date_details(date_mark) + ")"
  else:
    chart_date = util.get_date_iso8601(date_mark)
  i = 1
  with open(readfilepath, "r") as f:
    line = f.readline().strip("\n")
    while line:
      content = line.split(",")
      if i == 1:
        title = content
        break
      i = i + 1
  for index in range(len(title)-1):
    if index == 0:
      continue
    output_file = out_f + "_" + title[index]    ## bs_thread_mode
    i = 0
    record = ""
    first_col = ""
    col_var = ""
    with open(readfilepath, "r") as f:
      line = f.readline().strip("\n")
      while line:
        i = i + 1
        if i == 1:
          line = f.readline().strip("\n")
          continue
        else:
          content = line.split(',')
        col_var = content[0]
        if col_var.startswith("'"):
           col_var = col_var[1:]
        if col_var.endswith("'"):
           col_var = col_var.strip("'")
        if len(first_col) == 0:
          first_col = col_var
        else:
          first_col = first_col + "_" + col_var
        if len(record) == 0:
          record = content[index]
        else:
          record = record + "," + content[index]
        line = f.readline().strip("\n")
    output_file = output_file + "_" + first_col
    write_file_path = os.path.join(writedir, output_file)
    if outputcsv:
       write_file_path = write_file_path + ".csv"
       if not os.path.exists(write_file_path):
       ## write title
         with open(write_file_path, "a") as fw:
           write_content = "Date," + first_col.replace('_', ',') + "\n"
           fw.write(write_content)
    with open(write_file_path, "a") as fw:
       if outputcsv:
         write_content = chart_date + "," + record + "\n"
       else:
         write_content = "[" + chart_date + "," + record + "],\n"
       fw.write(write_content)

if __name__=="__main__":
  store_read_content("/home/honzhan/NginxRoot/Perf/20161216202615/fio_result/8k_1_bs_tbl_normal_csv",
                     ".+/(\d+)/[a-zA-Z_0-9/]+_bs_tbl_normal_csv",
                     "fiotrend", True)
