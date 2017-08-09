import sys,json

def extract_loc_from_azureloc():
  #data = sys.stdin.readlines()
  #print(data)
  obj = json.load(sys.stdin)
  print(obj[0]['name'])
  for i in range(len(obj)):
    print(obj[i]['name'])

if __name__=="__main__":
  extract_loc_from_azureloc
