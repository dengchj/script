# BACKUP-S3

## Overview

The project about backup of external data to UMStor object storage based on S3. Backup jobs are periodic tasks.
It is support external types:

- SQLServer data: PowerShell script on Windows.
- MySql data: shell script.
- common files: common files or directories on local file system, contains compression, packaging and upload.

## Usage

### SqlServer Backup

1.确定SqlServer 通过Windows 身份验证进行连接：[参考链接](https://docs.microsoft.com/zh-cn/sql/relational-databases/security/choose-an-authentication-mode?view=sql-server-ver15)

2.确定需要备份的数据库, powershell 脚本需要管理员权限执行

```PS1
PS C:\sqlserver_backup> .\backup.ps1 -DestBucket test1 -DBId sqlserver -BackupFileName data.rar
```

在UMStor 中的存储位置：/test1/2019/12/30/data.rar

### MySQL Backup

#### MySQL Linux

1.确定mysql.sock 及my.cnf 的位置

```no
(umstorlcm) [root@umstor14 mysql]# ll /data/mysql
总用量 0
drwxr-xr-x 2 root root 20 12月 26 20:13 conf
lrwxrwxrwx 1 root root 25 12月 26 20:15 mysqld.sock -> /var/lib/mysql/mysql.sock
(umstorlcm) [root@umstor14 mysql]# ll /data/mysql/conf/
总用量 0
lrwxrwxrwx 1 root root 11 12月 26 20:13 my.cnf -> /etc/my.cnf
```

2.确定安装python及boto3

3.mysql 的用户名及密码

```shell
[root@umstor14 mysql]# ./backup.sh /usr /data mysql test1 root r00tme mysqldbdump master
```

#### MySQL Windows

- Powershell 支持：Import-Module MySqlCmdlets  安装 it.wiechecki.mysql-cmdlet.rar
- 安装WinRAR：[C:\Program Files\WinRAR\Rar.exe]
- 本地备份目录：大容量数据盘
- MySQL 认证方式：需要选择legacy authentication method，否则脚本无法认证出错

```PS1
PS C:\mysql_backup_win> .\backup.ps1 -DestBucket test1 -DBId sqlserver -BackupFileName data.rar
```

### File Backup

#### Windows Files

若出现脚本执行权限问题：参考[ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-executionpolicy?view=powershell-6)

- 查看当前PS中脚本执行权限：
Get-ExecutionPolicy
Get-ExecutionPolicy -List

- 现在更改其限制，改为脚本可直接运行：
Set-ExecutionPolicy Unrestricted    #无限制，可执行任何脚本

```PS1
PS C:\win_backup> .\backup.ps1 -SourceDir c:\win_backup -DestBucket liudy01 -BackupFileName f.bak
```

定时任务使用：Windows 任务计划程序，创建基本任务

1) 程序或脚本：powershell
2) 添加参数：-file "C:\win_backup\backup.ps1" -SourceDir C:/win_backup -DestBucket liudy01 -BackupFileName winfile007

#### Linux Files

```no
[root@umstor14 filebak]# bash bak.sh /data/filebak test1
```

定时任务使用crond服务: /etc/cron.d/backup.conf
