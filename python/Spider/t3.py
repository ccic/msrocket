#coding:utf-8
import json
import unittest
from selenium import webdriver
from bs4 import BeautifulSoup


class seleniumTest(unittest.TestCase):
    def setUp(self):
        self.driver = webdriver.PhantomJS()

    def testEle(self):
        driver = self.driver
        driver.get('https://jinpiaotong.com/product/hy-allcount.pahtml?ver=I3I6HHG7&sort=0&orderBy=1')
        soup = BeautifulSoup(driver.page_source, 'xml')
        results = soup.find_all('pre')
        for result in results:
            json_re = result.get_text()
            print(json_re)
            data = json.loads(json_re)
            if data['code'] == 'SUCCESS':
                print(data['data']['count']) 
            

    def tearDown(self):
        print 'down'

if __name__ == "__main__":
    unittest.main()
