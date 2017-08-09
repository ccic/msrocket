import os,re
import shutil

webroot="NginxRoot/Perf/"
webapp="index.html"
placeholder="XXXXX"

def search_latest_dir(dir):
    max = 0
    d = os.listdir(dir)
    pat = re.compile(r"[0-9]+")
    for a in d:
        if os.path.isdir(dir + "/" + a) and pat.match(a):
            t = int(a)
            if max < t:
                max = t
    return str(max)

def replace(filename, oldstr, newstr):
    with open(filename) as fin:
        content = fin.read()
        newText = content.replace(oldstr, newstr)
    with open(filename, "w") as fout:
        fout.write(newText)

def create_tmpl():
    fn=webapp
    shutil.copy(webroot + webapp, fn)
    with open(fn) as f:
        c = f.read()
        result, result2 =re.subn("\d{14}", placeholder, c)
    with open(fn, "w") as f:
        f.write(result)

def create_new():
    s = search_latest_dir(webroot)
    replace(webapp, placeholder, s)

def update():
    fn=webapp
    shutil.copy(fn, webroot + webapp)

if __name__=="__main__":
    create_tmpl()
    create_new()
    update()
