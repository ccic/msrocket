import os,re
import util

def normal_throughput(value_list):
  valuestrs = value_list.split(",")
  normal_values = ""
  for idx in range(len(valuestrs)-1):
    v = str(int(float(valuestrs[idx])/1024/1024 * 100)/100.0)
    if len(normal_values) == 0:
       normal_values = v
    else:
       normal_values = normal_values + "," + v
  
  v = str(int(float(valuestrs[len(valuestrs)-1])/1024 * 100)/100.0)
  normal_values = normal_values + "," + v

  return normal_values

def read_content(readfilepath, pattern, writedir, is_outputcsv):
  conn_2_content = {}
  date_mark = None
  match = re.match(pattern, readfilepath)
  if match:
    date_mark = match.group(1)
    if not is_outputcsv:
       date_mark = "new_Date(" + util.get_date_details(date_mark) + ")"
    else:
       date_mark = util.get_date_iso8601(date_mark)

  i = 1
  with open(readfilepath, "r") as f:
    line = f.readline().strip("\n")
    while line:
      if i == 1:
        title = line
      else:
        content = line.split(",", 2)
        if title.find("(") == -1:
           normals = normal_throughput(content[2])
        else:
           normals = content[2]
        conn_2_content[content[0]] = normals
      line = f.readline().strip("\n")
      i = i + 1
  
  title_items = title.split(",")
  file_info = ""
  for idx in range(len(title_items)):
    if idx == 0 or idx == 1: ## skip connection_no and durations
      continue
    col = title_items[idx]
    if len(file_info) == 0:
       file_info = col
    else:
       file_info = file_info + "_" + col
  for k,v in conn_2_content.items():
    #print "key:'" + k + "' values:'" + v + "'"
    out_file = k + "_" + file_info
    writefile = os.path.join(writedir, out_file)
    if is_outputcsv:
      writefile = writefile + ".csv"
      if not os.path.exists(writefile):
        with open(writefile, "a") as fw:
          write_content = "Date," + file_info.replace('_', ',') + "\n"
          fw.write(write_content)

    with open(writefile, "a") as fw:
      if is_outputcsv:
        write_content = date_mark + "," + v + "\n"
      else:
        write_content = "[" + date_mark + "," + v + "],\n"
      fw.write(write_content)


if __name__=="__main__":
  read_content("/home/honzhan/NginxRoot/Perf/20160515002601/k_table.csv", "trend", False)
