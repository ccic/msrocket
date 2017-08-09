#coding:utf-8
import urllib
import urllib2
import json
from selenium import webdriver
from bs4 import BeautifulSoup

def getAllProd(investUrl):
    pUrl = investUrl
    headers={'Content-Type':'application/x-www-form-urlencoded'}
    values={'Cmd':'GetProductPageList', 'pagesize':'10', 'pageindex':'1', 'type':'0'}
    data = urllib.urlencode(values)
    req = urllib2.Request(pUrl, data, headers)
    resp = urllib2.urlopen(req)
    result = resp.read()
    try:
        jdata = json.loads(result)
        return jdata
    except ValueError, e:
        print("Timeout and try again")

    bs = BeautifulSoup(result, 'lxml')
    upUrl = bs.find("meta")["content"].split()[1]
    pUrl = "https://dq.tuandai.com" + upUrl[4:]
    print(pUrl)
    req = urllib2.Request(pUrl, data, headers)
    resp = urllib2.urlopen(req)
    result = resp.read()
    bs = BeautifulSoup(result, 'lxml')
    print(bs)
    jdata = json.loads(bs.find('p'))
    print(jdata)
    return jdata

def getEveryProd(allProds):
    url="https://dq.tuandai.com/ajaxCross/ajax_invest.ashx"
    total = allProds['total']
    for p in allProds['ProductList']:
        prodId = p['Id']
        orderCount = p['OrderCount']
        pageSize = 10
        pageIndex = 1
        left = 0
        if (orderCount % pageSize) > 0:
            left = 1
        else:
            left = 0
        pages = orderCount / pageSize + left
        #print("=={0}".format(orderCount))
        for k in range(1, 2):
            headers={'Content-Type':'application/x-www-form-urlencoded'}
            values={'Cmd':'GetWePlanSubscribeList', 'pagesize':'10', 'pageindex':k, 'projectid':prodId}
            data=urllib.urlencode(values)
            req = urllib2.Request(url, data, headers)
            resp = urllib2.urlopen(req)
            res = resp.read()
            print(res)

def getUrl(url, sub):
    driver = webdriver.PhantomJS()
    driver.get(url + sub)
    #print(driver.page_source)
    #driver.find_element_by_xpath()
    soup = BeautifulSoup(driver.page_source, 'xml')
    alist = soup.select("#welist > table > tbody > tr > td > a")
    for a in alist:
        href=a['href']
        #href="/pages/weplan/WeAYB_Detail.aspx?id=2e1a38dd-5954-42e4-b8e3-2bd7dd73056d"
        prodSubUrl = href.split('?')[0]
        prodId = href.split('=')[1]
        pUrl = "https://dq.tuandai.com/ajaxCross/ajax_invest.ashx"
        headers={'Content-Type':'application/x-www-form-urlencoded'}
        values={'Cmd':'GetWePlanSubscribeList', 'pagesize':'15', 'pageindex':'1', 'type':'0'}
        data=urllib.urlencode(values)
        req = urllib2.Request(pUrl, data, headers)
        resp = urllib2.urlopen(req)
        result = resp.read()
        print(result)

def parseTuanDaiDQ():
    allProdJson = getAllProd('https://dq.tuandai.com/pages/ajax/invest_list.ashx')
    getEveryProd(allProdJson)
    
if __name__=="__main__":
    parseTuanDaiDQ()
