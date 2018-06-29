#!/usr/bin/env python
# -*- coding: UTF-8 -*-
import datetime
import time
import os

'''
open time:9:30~11:30 13:00~15:00

'''

def re_run():
    print 'run devDaemon.py'
    status = os.system('python ./devDaemon.py')
    print status
    print status>>8

def main():
    hour_am = 9
    min_am = 20    #提前开市10分钟重启
    hour_pm = 12
    min_pm = 50    #提前开市10分钟重启
    while True:
        now = datetime.datetime.now()
        wd = now.isoweekday()
        if wd == 6 or wd == 7: #周六或周日
            print 'Today is %d' % wd
            time.sleep(3600)
        else:
            print 'Today is work day %d' % wd
            if (now.hour==hour_am and now.minute==min_am) or (now.hour==hour_pm and now.minute==min_pm):
                re_run()
            else:
                time.sleep(20)

if __name__ == '__main__':
    main()
