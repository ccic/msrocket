#coding:utf-8
import json
import log as logging
import pymongo
import unittest
import urllib
from selenium import webdriver
from bs4 import BeautifulSoup

LOG = logging.getLogger()

class seleniumTest(unittest.TestCase):
    _dbUser="root"
    _dbPass="Hackathon2017"
    _dbHost="10.172.2.139"

    def setUp(self):
        self.driver = webdriver.PhantomJS()

    def _extract_json_from_xml(self, drv):
        soup = BeautifulSoup(drv.page_source, 'xml')
        results = soup.find_all('pre')
        jdata = json.loads(results[0].get_text())
        return jdata

    def _get_content(self, drv, url):
        drv.get(url)
        jdata = self._extract_json_from_xml(drv)
        return jdata

    def _get_db_conn(self):
        passwd = urllib.quote_plus(self._dbPass)
        dbUrl = 'mongodb://' + self._dbUser + ":" + passwd + '@' + self._dbHost
        conn = pymongo.MongoClient(dbUrl)
        return conn

    def _insert_if_not_exist(self, dbTbl, jdata):
        idv = jdata['id']
        exist = dbTbl.find_one({'id': jdata['id']})
        if exist is None:
            dbTbl.insert_one(jdata)
        else:
            print("Data existing: {0}".format(idv))

    def testEle(self):
        dbConn = self._get_db_conn()
        jpt = dbConn['jinpiaotong']
        hyp = jpt['huiyin_prod']

        driver = self.driver
        driver.get('https://jinpiaotong.com/product/productHy.html')
        elem = driver.find_element_by_xpath(
                 '//div[@id="pageBar"]/div/ul/li[@type="last"]')
        elem.click()
        pg = driver.find_element_by_xpath(
                 '//div[@id="pageBar"]/div/ul/li[@class="pgNumbers"]/ul/li[last()]')
        lastPage = int(pg.get_attribute('idx'))
        firstPage = 1
        ## iterate all product
        for i in range(firstPage, lastPage):
            url = "https://jinpiaotong.com/product/hy.pahtml?"\
                  "ver=N4MGW7CJ&sort=0&orderBy=1&page={0}&ordby=".format(i)
            jdata = self._get_content(driver, url)
            if jdata['code'] == 'SUCCESS':
                for jd in jdata['data']:
                    self._insert_if_not_exist(hyp, jd)
                    prodId = jd['id']
                    prodNo = jd['productNo']
                    tbl = "hy_" + prodId + "_" + prodNo
                    if tbl in jpt.collection_names():
                       continue
                    prodUrl = "https://jinpiaotong.com/product/orders-allcount.pahtml?"\
                              "ver=95QIT44J&productNo={0}".format(prodNo)
                    prodJdata = self._get_content(driver, prodUrl)
                    if prodJdata['code'] != 'SUCCESS':
                        print("Error")
                        continue
                    count = int(prodJdata['data']['count'])
                    pageSize = int(prodJdata['data']['pageSize'])
                    left = 0
                    if (count % pageSize) > 0:
                        left = 1
                    else:
                        left = 0
                    totalPage = count / pageSize + left
                    print("count: {0}, pageSize: {1}, totalPage: {2}".format(count, pageSize, totalPage))
                    if totalPage > 0:
                        for k in range(1, totalPage):
                            invDetailReq = "https://jinpiaotong.com/product/orders.pahtml?"\
                                           "ver=95QIT44J&page={0}&productNo={1}".format(k, prodNo)
                            investData = self._get_content(driver, invDetailReq)
                            if investData['code'] == 'SUCCESS':
                                for userdat in investData['data']:
                                    jpt[tbl].insert_one(userdat)

    def tearDown(self):
        print 'down'

if __name__ == "__main__":
    #logging.setupBasicLogging()
    unittest.main()
