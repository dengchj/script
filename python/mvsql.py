#!/usr/bin/python
# -*- coding: UTF-8 -*-

import pymysql
pymysql.install_as_MySQLdb()
import MySQLdb
import re
import traceback

# 打开数据库连接
db = MySQLdb.connect("dbaddr", "dbuser", "dbpwd", "dbname", charset='utf8' )

# 使用cursor()方法获取操作游标
cursor = db.cursor()

sql_q = 'select code,change_unit from kyad.t_code_info'

try:
   # 执行SQL语句
   cursor.execute(sql_q)
   # 获取所有记录列表
   results = cursor.fetchall()
   for row in results:
      code = row[0]
      ch_unit = row[1]
      # 打印结果
      cun = re.findall(r"\d+\.?\d*",ch_unit)
      print ('code=%s,change unit=%s,num=%s' %(code,ch_unit,cun[0]))
      sql_ud = ''' update kyad.t_code_info set change_unit_num = %s where code = '%s' ''' %(cun[0],code)
      print(sql_ud)
      try:
         # 执行sql语句
         cursor.execute(sql_ud)
         # 提交到数据库执行
         db.commit()
      except:
         print('Rollback in case there is any error')
         traceback.print_exc()
         db.rollback()

except:
   print ("Error: unable to fecth data, exception:%r" % Exception)
   traceback.print_exc()

# 关闭数据库连接
db.close()
